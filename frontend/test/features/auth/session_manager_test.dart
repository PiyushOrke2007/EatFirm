import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatfirm/features/auth/models/user_model.dart';
import 'package:eatfirm/features/auth/services/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionManager Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with empty state when no token stored', () async {
      final sessionManager = SessionManager();
      await sessionManager.init();

      expect(sessionManager.isInitialized, true);
      expect(sessionManager.token, isNull);
      expect(sessionManager.currentUser, isNull);
      expect(sessionManager.isAuthenticated, false);
      expect(sessionManager.role, isNull);
    });

    test(
      'Saves session, persists token & user, and notifies listeners',
      () async {
        final sessionManager = SessionManager();
        await sessionManager.init();

        bool listenerNotified = false;
        sessionManager.addListener(() {
          listenerNotified = true;
        });

        const user = UserModel(
          id: 'usr-42',
          name: 'Bob Delivery',
          role: UserRole.deliveryPartner,
          accountStatus: 'ACTIVE',
          isVerified: true,
        );

        await sessionManager.saveSession('mock-jwt-token-xyz', user);

        expect(sessionManager.isAuthenticated, true);
        expect(sessionManager.token, 'mock-jwt-token-xyz');
        expect(sessionManager.currentUser?.name, 'Bob Delivery');
        expect(sessionManager.role, UserRole.deliveryPartner);
        expect(listenerNotified, true);

        // Verify re-initialization restores persisted state
        final newSessionManager = SessionManager();
        await newSessionManager.init();
        expect(newSessionManager.isAuthenticated, true);
        expect(newSessionManager.currentUser?.id, 'usr-42');
        expect(newSessionManager.token, 'mock-jwt-token-xyz');
      },
    );

    test('Clears session on logout', () async {
      final sessionManager = SessionManager();
      await sessionManager.init();

      const user = UserModel(
        id: 'usr-1',
        name: 'Alice',
        role: UserRole.customer,
        accountStatus: 'ACTIVE',
        isVerified: false,
      );

      await sessionManager.saveSession('token-123', user);
      expect(sessionManager.isAuthenticated, true);

      await sessionManager.clearSession();
      expect(sessionManager.isAuthenticated, false);
      expect(sessionManager.token, isNull);
      expect(sessionManager.currentUser, isNull);
    });

    test('Updates user profile in session', () async {
      final sessionManager = SessionManager();
      await sessionManager.init();

      const user = UserModel(
        id: 'usr-1',
        name: 'Alice',
        role: UserRole.customer,
        accountStatus: 'ACTIVE',
        isVerified: false,
      );

      await sessionManager.saveSession('token-123', user);
      final updated = user.copyWith(name: 'Alice Wonder', isVerified: true);

      await sessionManager.updateUser(updated);
      expect(sessionManager.currentUser?.name, 'Alice Wonder');
      expect(sessionManager.currentUser?.isVerified, true);
    });
  });
}
