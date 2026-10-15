import 'package:flutter/widgets.dart';

/// The widest the payment content gets; on a tablet it stays a readable column.
const double paymentContentMaxWidth = 560;

class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: paymentContentMaxWidth),
        child: child,
      ),
    );
  }
}
