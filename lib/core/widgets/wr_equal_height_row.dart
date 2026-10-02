import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Hàng các ô cùng bề ngang, cùng chiều cao bằng ô CAO NHẤT.
///
/// Thay cho `IntrinsicHeight(Row(stretch, Expanded...))`. Bản đó dựa vào phép đo
/// "cao nhất có thể" (intrinsic) của từng ô, tách khỏi lần layout thật; khi hai
/// phép đo lệch nhau (ảnh test web 320px: nhãn xuống 3 dòng mà hàng chỉ cao đủ 2
/// dòng) thì dòng cuối bị cắt. Ở đây chiều cao lấy từ chính lần layout thật:
/// dựng mỗi ô với bề ngang cố định, đọc chiều cao thật, rồi ép cả hàng bằng ô
/// cao nhất. Không có phép đo thứ hai nào để lệch.
class WrEqualHeightRow extends MultiChildRenderObjectWidget {
  const WrEqualHeightRow({super.key, super.children, this.gap = 0});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualHeightRow(gap);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBox renderObject,
  ) {
    (renderObject as _RenderEqualHeightRow).gap = gap;
  }
}

class _Pd extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _Pd>,
        RenderBoxContainerDefaultsMixin<RenderBox, _Pd> {
  _RenderEqualHeightRow(this._gap);

  double _gap;
  double get gap => _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Pd) child.parentData = _Pd();
  }

  double _childWidth(BoxConstraints c) {
    final n = childCount;
    if (n == 0) return 0;
    return math.max(0, (c.maxWidth - _gap * (n - 1)) / n);
  }

  @override
  void performLayout() {
    final w = _childWidth(constraints);
    var tallest = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      c.layout(BoxConstraints.tightFor(width: w), parentUsesSize: true);
      tallest = math.max(tallest, c.size.height);
    }
    var x = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      c.layout(BoxConstraints.tightFor(width: w, height: tallest));
      (c.parentData! as _Pd).offset = Offset(x, 0);
      x += w + _gap;
    }
    size = constraints.constrain(Size(constraints.maxWidth, tallest));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final w = _childWidth(constraints);
    var tallest = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      tallest = math.max(
        tallest,
        c.getDryLayout(BoxConstraints.tightFor(width: w)).height,
      );
    }
    return constraints.constrain(Size(constraints.maxWidth, tallest));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
