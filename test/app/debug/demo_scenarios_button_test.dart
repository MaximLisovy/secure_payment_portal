import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/debug/brand_switcher.dart';
import 'package:secure_payment_portal/app/debug/demo_scenarios_button.dart';
import 'package:secure_payment_portal/app/debug/demo_scenarios_panel.dart';
import 'package:secure_payment_portal/app/debug/simulation_badge.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';

import '../../helpers/fake_bills.dart';
import '../../helpers/pump_app.dart';

const _statusBar = 40.0;
const _bottomInset = 24.0;

/// A page with the debug actions in its app bar, on a screen too short for the
/// whole panel and with a status bar and a bottom inset to respect.
Future<void> _pumpPage(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(400, 640)
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: _statusBar, bottom: _bottomInset)
    ..viewPadding = const FakeViewPadding(
      top: _statusBar,
      bottom: _bottomInset,
    );
  addTearDown(tester.view.reset);
  await tester.pumpApp(
    Scaffold(
      appBar: AppBar(
        title: const Text('Page'),
        actions: const [
          SimulationBadge(),
          DemoScenariosButton(),
          BrandSwitcher(),
        ],
      ),
      body: const SizedBox.expand(),
    ),
    brand: retailBrand,
    overrides: [
      fakePaymentRemoteDataSourceProvider.overrideWithValue(
        FakePaymentRemoteDataSource(bills: FakeBills.all),
      ),
      // No real source: everything is simulated, so the badge shows.
      realSecurityPlatformDataSourceProvider.overrideWithValue(null),
      realPaymentPlatformDataSourceProvider.overrideWithValue(null),
    ],
  );
}

Finder get _openButton => find.byTooltip(AppStrings.demoScenarios);

Future<void> _pressOpenButton(WidgetTester tester) async {
  await tester.tap(_openButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the panel never reaches above the app bar', (tester) async {
    await _pumpPage(tester);
    await _pressOpenButton(tester);

    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final sheet = tester.getRect(find.byType(BottomSheet));

    // The bar's own bottom edge, status bar included: whatever height the
    // brand's theme gives the toolbar.
    expect(appBarBottom, greaterThan(_statusBar));
    // The whole panel does not fit, so the sheet takes all the room below the
    // app bar and not a pixel more.
    expect(sheet.top, appBarBottom);
  });

  testWidgets('the panel scrolls inside the sheet to its last control', (
    tester,
  ) async {
    await _pumpPage(tester);
    await _pressOpenButton(tester);
    final restart = find.text(AppStrings.demoRestart);
    final sheet = tester.getRect(find.byType(BottomSheet));

    expect(
      tester.getRect(restart).top,
      greaterThan(sheet.bottom),
      reason: 'the last control starts out of view',
    );

    await tester.dragUntilVisible(
      restart,
      find.descendant(
        of: find.byType(DemoScenariosPanel),
        matching: find.byType(SingleChildScrollView),
      ),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    final button = tester.getRect(restart);
    expect(button.bottom, lessThanOrEqualTo(sheet.bottom - _bottomInset));
    expect(button.top, greaterThanOrEqualTo(sheet.top));
  });

  testWidgets('the badge and the brand switcher stay visible and tappable', (
    tester,
  ) async {
    await _pumpPage(tester);
    await _pressOpenButton(tester);

    expect(find.text(AppStrings.simulatedBadge).hitTestable(), findsOneWidget);
    expect(find.byType(BrandSwitcher).hitTestable(), findsOneWidget);

    await tester.tap(find.byType(BrandSwitcher));
    await tester.pumpAndSettle();

    expect(
      find.byType(PopupMenuItem<String>),
      findsWidgets,
      reason: 'the tap reached the switcher, not a barrier over the app bar',
    );
    expect(find.byType(DemoScenariosPanel), findsOneWidget);
  });

  testWidgets('pressing the button again closes the panel', (tester) async {
    await _pumpPage(tester);
    await _pressOpenButton(tester);
    expect(find.byType(DemoScenariosPanel), findsOneWidget);

    await _pressOpenButton(tester);
    expect(find.byType(DemoScenariosPanel), findsNothing);

    await _pressOpenButton(tester);
    expect(find.byType(DemoScenariosPanel), findsOneWidget);
  });
}
