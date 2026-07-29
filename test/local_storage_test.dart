import 'package:zerogate/data/local_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('authentication state is kept only in the current process', () async {
    SharedPreferences.setMockInitialValues({'authenticated': true});

    expect(await LocalStorage.isAuthenticated(), isFalse);

    await LocalStorage.login();
    expect(await LocalStorage.isAuthenticated(), isTrue);

    await LocalStorage.logout();
    expect(await LocalStorage.isAuthenticated(), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('authenticated'), isNull);
  });

  test('app password is verified from a secure hash', () async {
    await LocalStorage.saveAppPassword('senha-segura');

    expect(await LocalStorage.hasAppPassword(), isTrue);
    expect(await LocalStorage.verifyAppPassword('senha-segura'), isTrue);
    expect(await LocalStorage.verifyAppPassword('senha-errada'), isFalse);
  });

  test('cloudflare token is stored in secure storage', () async {
    await LocalStorage.saveToken('cf-token');

    expect(await LocalStorage.getToken(), 'cf-token');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cf_api_token'), isNull);
  });

  test('language preference is stored in shared preferences', () async {
    expect(await LocalStorage.getLanguage(), 'system');

    await LocalStorage.saveLanguage('en');

    expect(await LocalStorage.getLanguage(), 'en');
  });

  test('selected account is persisted and can be cleared', () async {
    expect(await LocalStorage.getSelectedAccountId(), isNull);

    await LocalStorage.saveSelectedAccount('acc-123', 'My Account');

    expect(await LocalStorage.getSelectedAccountId(), 'acc-123');
    expect(await LocalStorage.getSelectedAccountName(), 'My Account');

    await LocalStorage.clearSelectedAccount();

    expect(await LocalStorage.getSelectedAccountId(), isNull);
    expect(await LocalStorage.getSelectedAccountName(), isNull);
  });

  test('pinned accounts are toggled and persisted by ID', () async {
    expect(await LocalStorage.getPinnedAccountIds(), isEmpty);

    await LocalStorage.togglePinnedAccount('acc-1');
    await LocalStorage.togglePinnedAccount('acc-2');

    expect(await LocalStorage.getPinnedAccountIds(), {'acc-1', 'acc-2'});

    await LocalStorage.togglePinnedAccount('acc-1');

    expect(await LocalStorage.getPinnedAccountIds(), {'acc-2'});
  });
}
