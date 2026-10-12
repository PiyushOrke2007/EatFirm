export type RestaurantApprovalStatus = 'PENDING_APPROVAL' | 'APPROVED' | 'REJECTED';

export type DayOfWeek =
  | 'MONDAY'
  | 'TUESDAY'
  | 'WEDNESDAY'
  | 'THURSDAY'
  | 'FRIDAY'
  | 'SATURDAY'
  | 'SUNDAY';

export interface OperatingHour {
  id: string;
  restaurantId: string;
  dayOfWeek: DayOfWeek;
  openTime: string; // HH:MM
  closeTime: string; // HH:MM
  isClosed: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface OperatingHourInput {
  dayOfWeek: DayOfWeek;
  openTime: string;
  closeTime: string;
  isClosed?: boolean;
}

export interface Restaurant {
  id: string;
  ownerId: string;
  name: string;
  description: string | null;
  address: string;
  phone: string;
  cuisineType: string;
  foodLicenseNumber: string;
  imageUrl: string | null;
  approvalStatus: RestaurantApprovalStatus;
  rejectionReason: string | null;
  isOpen: boolean;
  latitude?: number;
  longitude?: number;
  averageRating?: number | null;
  ratingCount?: number;
  estimatedDeliveryMins?: number;
  priceTier?: string;
  distanceKm?: number;
  createdAt: string;
  updatedAt: string;
  operatingHours?: OperatingHour[];
}

export type BrowseSortOption =
  | 'relevance'
  | 'rating_desc'
  | 'distance_asc'
  | 'delivery_time_asc'
  | 'cost_low_to_high'
  | 'cost_high_to_low';

export interface BrowseRestaurantsQuery {
  search?: string;
  cuisine?: string;
  minRating?: number;
  maxDistanceKm?: number;
  maxDeliveryMins?: number;
  priceTier?: string;
  vegOnly?: boolean;
  isOpenOnly?: boolean;
  latitude?: number;
  longitude?: number;
  sortBy?: BrowseSortOption;
  page?: number;
  limit?: number;
}

export interface SearchSuggestion {
  type: 'restaurant' | 'dish' | 'cuisine';
  text: string;
  subtext?: string;
  id?: string;
}

export interface CustomerRestaurantDetails extends Restaurant {
  categories: (MenuCategory & { items: MenuItem[] })[];
  featuredItems?: MenuItem[];
  menuItems?: MenuItem[];
}

export interface MenuCategory {
  id: string;
  restaurantId: string;
  name: string;
  sortOrder: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
  itemCount?: number;
}

export interface MenuItem {
  id: string;
  restaurantId: string;
  categoryId: string;
  categoryName?: string;
  name: string;
  description: string | null;
  price: string; // Numeric string format "150.00"
  isVeg: boolean;
  imageUrl: string | null;
  isAvailable: boolean;
  availableFrom: string | null; // HH:MM
  availableUntil: string | null; // HH:MM
  isSpecialOffer: boolean;
  offerPrice: string | null; // Numeric string format "120.00"
  createdAt: string;
  updatedAt: string;
}

export interface OnboardRestaurantInput {
  name: string;
  description?: string;
  address: string;
  phone: string;
  cuisineType: string;
  foodLicenseNumber: string;
  imageUrl?: string;
  operatingHours?: OperatingHourInput[];
}

export interface UpdateRestaurantInput {
  name?: string;
  description?: string;
  address?: string;
  phone?: string;
  cuisineType?: string;
  foodLicenseNumber?: string;
  imageUrl?: string;
}

export interface CreateCategoryInput {
  name: string;
  sortOrder?: number;
}

export interface UpdateCategoryInput {
  name?: string;
  sortOrder?: number;
  isActive?: boolean;
}

export interface CreateMenuItemInput {
  categoryId: string;
  name: string;
  description?: string;
  price: number | string;
  isVeg?: boolean;
  imageUrl?: string;
  isAvailable?: boolean;
  availableFrom?: string | null;
  availableUntil?: string | null;
  isSpecialOffer?: boolean;
  offerPrice?: number | string | null;
}

export interface UpdateMenuItemInput {
  categoryId?: string;
  name?: string;
  description?: string;
  price?: number | string;
  isVeg?: boolean;
  imageUrl?: string;
  isAvailable?: boolean;
  availableFrom?: string | null;
  availableUntil?: string | null;
  isSpecialOffer?: boolean;
  offerPrice?: number | string | null;
}

