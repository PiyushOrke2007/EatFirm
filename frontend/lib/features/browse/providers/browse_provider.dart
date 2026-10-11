import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../restaurant/models/restaurant_model.dart';
import '../models/browse_filter_model.dart';
import '../models/search_suggestion_model.dart';
import '../services/browse_api_service.dart';

/// State management for Restaurant Discovery, Filters, Search & Comparison (SRS BROWSE-1..4).
class BrowseProvider extends ChangeNotifier {
  final BrowseApiService browseService;

  BrowseFilterModel _filter = const BrowseFilterModel(
    latitude: 12.9716,
    longitude: 77.5946,
    sortBy: 'relevance',
  );

  List<RestaurantModel> _restaurants = [];
  int _total = 0;
  int _page = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Search auto-complete suggestions
  List<SearchSuggestionModel> _suggestions = [];
  bool _isSuggestionsLoading = false;
  Timer? _debounceTimer;

  // Comparison drawer state (max 3 restaurants per BROWSE-4)
  final List<RestaurantModel> _comparedRestaurants = [];

  BrowseProvider({required this.browseService}) {
    loadRestaurants();
  }

  BrowseFilterModel get filter => _filter;
  List<RestaurantModel> get restaurants => _restaurants;
  int get total => _total;
  int get page => _page;
  int get totalPages => _totalPages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<SearchSuggestionModel> get suggestions => _suggestions;
  bool get isSuggestionsLoading => _isSuggestionsLoading;
  List<RestaurantModel> get comparedRestaurants => List.unmodifiable(_comparedRestaurants);

  bool isComparing(String id) => _comparedRestaurants.any((r) => r.id == id);

  /// Loads restaurant list according to active filters.
  Future<void> loadRestaurants({bool refresh = true}) async {
    if (refresh) {
      _page = 1;
      _filter = _filter.copyWith(page: 1);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await browseService.browseRestaurants(_filter);
      if (refresh) {
        _restaurants = result.restaurants;
      } else {
        final existingIds = _restaurants.map((r) => r.id).toSet();
        for (final r in result.restaurants) {
          if (!existingIds.contains(r.id)) {
            _restaurants.add(r);
            existingIds.add(r.id);
          }
        }
      }
      _total = result.total;
      _page = result.page;
      _totalPages = result.totalPages;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates live search query with 300ms debounce for auto-complete suggestions (NFR-4).
  void onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _suggestions = [];
      _isSuggestionsLoading = false;
      _filter = _filter.copyWith(clearSearch: true);
      notifyListeners();
      loadRestaurants(refresh: true);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      _isSuggestionsLoading = true;
      notifyListeners();

      try {
        _suggestions = await browseService.getSearchSuggestions(query);
      } catch (_) {
        _suggestions = [];
      } finally {
        _isSuggestionsLoading = false;
        notifyListeners();
      }
    });
  }

  /// Submits explicit search query.
  void submitSearch(String query) {
    _debounceTimer?.cancel();
    _suggestions = [];
    _filter = _filter.copyWith(
      search: query.trim().isNotEmpty ? query.trim() : null,
      clearSearch: query.trim().isEmpty,
    );
    loadRestaurants(refresh: true);
  }

  /// Selects suggestion from auto-complete.
  void selectSuggestion(SearchSuggestionModel suggestion) {
    _suggestions = [];
    if (suggestion.type == 'cuisine') {
      _filter = _filter.copyWith(cuisine: suggestion.text, clearSearch: true);
    } else {
      _filter = _filter.copyWith(search: suggestion.text);
    }
    loadRestaurants(refresh: true);
  }

  /// Sets pure veg filter (BROWSE-3, NFR-12).
  void toggleVegOnly(bool? vegOnly) {
    _filter = _filter.copyWith(
      vegOnly: vegOnly,
      clearVegOnly: vegOnly != true,
    );
    loadRestaurants(refresh: true);
  }

  /// Updates cuisine filter chip.
  void setCuisine(String? cuisine) {
    if (_filter.cuisine == cuisine) {
      _filter = _filter.copyWith(clearCuisine: true);
    } else {
      _filter = _filter.copyWith(cuisine: cuisine);
    }
    loadRestaurants(refresh: true);
  }

  /// Updates sort order.
  void setSortBy(String sortBy) {
    _filter = _filter.copyWith(sortBy: sortBy);
    loadRestaurants(refresh: true);
  }

  /// Applies advanced filters from bottom sheet.
  void applyFilters(BrowseFilterModel newFilter) {
    _filter = newFilter;
    loadRestaurants(refresh: true);
  }

  /// Resets all filters back to default.
  void resetFilters() {
    _filter = const BrowseFilterModel(
      latitude: 12.9716,
      longitude: 77.5946,
      sortBy: 'relevance',
    );
    loadRestaurants(refresh: true);
  }

  /// Toggles restaurant in comparison shelf (maximum 3 per BROWSE-4).
  bool toggleCompareRestaurant(RestaurantModel restaurant) {
    final index = _comparedRestaurants.indexWhere((r) => r.id == restaurant.id);
    if (index >= 0) {
      _comparedRestaurants.removeAt(index);
      notifyListeners();
      return false;
    } else {
      if (_comparedRestaurants.length >= 3) {
        return false; // Reached limit
      }
      _comparedRestaurants.add(restaurant);
      notifyListeners();
      return true;
    }
  }

  void removeFromCompare(String restaurantId) {
    _comparedRestaurants.removeWhere((r) => r.id == restaurantId);
    notifyListeners();
  }

  void clearComparison() {
    _comparedRestaurants.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
