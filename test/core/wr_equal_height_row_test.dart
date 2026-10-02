// Cơ chế gây lỗi cắt chữ ô check-in: hàng cao theo phép đo intrinsic, mà phép
// đo ấy có thể thấp hơn chiều cao layout thật. Ô "nói dối" dưới đây mô phỏng
// đúng điều đó.
//
// Run: flutter test test/core/wr_equal_height_row_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/widgets/wr_equal_height_row.dart';

/// Layout thật cao [real], nhưng khai intrinsic chỉ [claimed].
class _Liar extends LeafRenderObjectWidget {
  const _Liar(this.real, this.claimed);
  final double real, claimed;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLiar(real, claimed);
}

class _RenderLiar extends RenderBox {
  _RenderLiar(this.real, this.claimed);
  final double real, claimed;
  @override
  double computeMinIntrinsicHeight(double w) => claimed;
  @override
  double computeMaxIntrinsicHeight(double w) => claimed;
  @override
  Size computeDryLayout(BoxConstraints c) =>
      c.constrain(Size(c.maxWidth, real));
  @override
  void performLayout() => size = computeDryLayout(constraints);
}

Widget _host(Widget row) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 300, child: row),
  ),
);

void main() {
  testWidgets('IntrinsicHeight+Row hàng thấp hơn ô thật (tái hiện lỗi)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(child: _Liar(90, 60)),
              Expanded(child: _Liar(40, 40)),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Row)).height, 60);
  });

  testWidgets('WrEqualHeightRow cao bằng ô thật cao nhất, hai ô bằng nhau', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const WrEqualHeightRow(
          gap: 12,
          children: [_Liar(90, 60), _Liar(40, 40)],
        ),
      ),
    );
    expect(tester.getSize(find.byType(WrEqualHeightRow)).height, 90);
    final liars = find.byType(_Liar);
    expect(tester.getSize(liars.at(0)), const Size(144, 90));
    expect(tester.getSize(liars.at(1)), const Size(144, 90));
    expect(tester.getTopLeft(liars.at(1)).dx, 156);
  });
}
