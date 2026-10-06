// Sheet "Lưu lại hành trình của bạn" (`saveSheetHTML`, mockup v47).
//
// Hiện cho khách 1,1 giây sau màn Xong của lần nhìn lại đầu tiên, MỘT lần.
// Chốt 06/10: đợt này chỉ có Email. Apple và Google làm sau (App Store 4.8:
// có Google thì phải có Sign in with Apple), nên nút Email đứng ở vị trí nút
// chính của mockup.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/theme/wr_colors.dart';

/// Mở sheet. Trả về khi sheet đóng (người dùng chọn Email hoặc Để sau).
Future<void> showSaveJourneySheet(BuildContext context) async {
  final router = GoRouter.of(context);
  final choice = await showModalBottomSheet<_SaveChoice>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x61091634),
    builder: (_) => const WrSaveJourneySheet(),
  );
  if (choice == _SaveChoice.email) {
    await router.push<void>('/auth/save');
  }
}

enum _SaveChoice { email, later }

class WrSaveJourneySheet extends StatelessWidget {
  const WrSaveJourneySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_save_journey_sheet'),
      decoration: const BoxDecoration(
        color: WrColors.pageBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2E093774),
            blurRadius: 40,
            offset: Offset(0, -12),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        10,
        22,
        22 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0x29093774),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            tr('Dấu ấn đầu tiên', 'Your first mark').toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: WrColors.text3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('Lưu lại hành trình của bạn', 'Keep your journey'),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: WrColors.navy,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Bạn vừa để lại dấu ấn đầu tiên. Tạo tài khoản để giữ nó an toàn, '
                  'kể cả khi bạn đổi điện thoại hoặc cài lại ứng dụng.',
              'You have just left your first mark. Create an account to keep '
                  'it safe, even if you change phones or reinstall the app.',
            ),
            style: const TextStyle(
              fontSize: 14.5,
              color: Color(0xBD2C335D),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: Color(0xFF0C8C88),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(
                    'Nội dung vẫn chỉ mình bạn xem được.',
                    'Only you can see what you write.',
                  ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0C8C88),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('wr_save_sheet_email'),
              onPressed: () => Navigator.of(context).pop(_SaveChoice.email),
              style: FilledButton.styleFrom(
                backgroundColor: WrColors.navy,
                foregroundColor: WrColors.cream,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(tr('Dùng email', 'Use email')),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              key: const Key('wr_save_sheet_later'),
              onPressed: () => Navigator.of(context).pop(_SaveChoice.later),
              style: TextButton.styleFrom(foregroundColor: WrColors.text2),
              child: Text(
                tr('Để sau', 'Later'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'Nếu chưa lưu, hành trình chỉ nằm trên thiết bị này và sẽ mất '
                  'khi bạn xóa ứng dụng.',
              'Until you save it, your journey lives only on this device and '
                  'will be lost if you delete the app.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: WrColors.text3,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
