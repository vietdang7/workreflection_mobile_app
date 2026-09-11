// Dọn sạch mọi thứ app còn nhớ về người vừa đăng xuất.
//
// VÌ SAO CẦN FILE NÀY
//
// Riverpod giữ giá trị của một provider suốt đời `ProviderScope`, mà
// `ProviderScope` thì sống từ lúc mở app đến lúc tắt hẳn. Đăng xuất rồi đăng
// nhập tài khoản khác KHÔNG dựng lại scope đó: mọi `FutureProvider` đã đọc
// xong vẫn ôm nguyên dữ liệu của người trước, nên màn Home chào tên tài khoản
// cũ cho tới khi người dùng tự tải lại màn.
//
// Nguy hiểm hơn phần hiển thị: [currentUserIdProvider] là `Provider` thuần,
// nó chụp `auth.currentUser?.id` đúng một lần rồi giữ mãi. Sau khi đổi tài
// khoản, những chỗ ghi dữ liệu theo id đó — ghi danh thực hành, cuộc trò
// chuyện, episode — sẽ ghi NHẦM SANG NGƯỜI CŨ. Đó là lý do phải xoá cả những
// provider không hiện gì lên màn hình.
//
// CÁCH LÀM
//
// Chỉ xoá những provider GỐC: định danh, repository và state của phiên làm
// việc. Mọi provider dữ liệu đều `ref.watch` một trong số đó, nên Riverpod tự
// dựng lại chúng theo — không cần (và không nên) liệt kê từng provider dữ
// liệu, vì danh sách đó mới là thứ chắc chắn sẽ thiếu sót khi thêm màn mới.
//
// ⚠ Thêm một repository mới thì thêm nó vào đây. Một repository đọc dữ liệu
//   theo user mà đứng ngoài danh sách sẽ tái hiện đúng lỗi rò dữ liệu trên.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/profile_providers.dart';
import '../../features/survey/survey_providers.dart';
import '../../features/video_report/data/video_report_repository.dart';
import '../../features/wr/episode_flow_controller.dart';
import '../../features/wr/wr_providers.dart';
import 'coaching_repository.dart';
import 'payment_repository.dart';
import 'roadmap_repository.dart';
import 'workshop_repository.dart';
import 'wr_chat_repository.dart';
import 'wr_content_repository.dart';
import 'wr_episode_repository.dart';
import 'wr_intelligence_repository.dart';
import 'wr_mood_content_repository.dart';
import 'wr_org_survey_repository.dart';
import 'wr_repository.dart';

/// Định danh người đang đăng nhập. Phải đứng đầu danh sách: mọi truy vấn theo
/// user đều bắt nguồn từ đây.
final List<ProviderOrFamily> userIdentityProviders = [
  currentUserIdProvider,
  currentUserEmailProvider,
];

/// Cửa đọc/ghi dữ liệu. Xoá là mọi `FutureProvider` đọc qua chúng phải hỏi lại
/// server bằng phiên đăng nhập mới.
final List<ProviderOrFamily> userDataProviders = [
  wrRepositoryProvider,
  surveyRepositoryProvider,
  wrIntelligenceRepositoryProvider,
  wrContentRepositoryProvider,
  wrEpisodeRepositoryProvider,
  wrChatRepositoryProvider,
  wrMoodContentRepositoryProvider,
  wrOrgSurveyRepositoryProvider,
  workshopRepositoryProvider,
  roadmapRepositoryProvider,
  coachingRepositoryProvider,
  videoReportRepositoryProvider,
  paymentRepositoryProvider,
];

/// State của phiên làm việc: những gì người dùng đang làm dở. Người mới đăng
/// nhập không được thừa hưởng một buổi nhìn lại hay một bài khảo sát dở dang
/// của người trước.
final List<ProviderOrFamily> userSessionStateProviders = [
  episodeFlowProvider,
  pendingMoodProvider,
  pendingEnergyProvider,
  surveyIntroInfoProvider,
  surveyIdInProgressProvider,
  currentQuestionIndexProvider,
  profileNudgeDismissedProvider,
  premiumOverrideProvider,
];

/// Toàn bộ provider phải xoá khi người đăng nhập thay đổi.
final List<ProviderOrFamily> userScopedProviders = [
  ...userIdentityProviders,
  ...userDataProviders,
  ...userSessionStateProviders,
];

// ---------------------------------------------------------------------------
// ĐỔI NGÔN NGỮ THÌ KHÔNG XOÁ GÌ CẢ — CỐ Ý
//
// Bản trước xoá đúng [userDataProviders] mỗi lần người dùng đổi ngôn ngữ, để
// buộc màn hình dựng lại. Nó chữa được triệu chứng nhưng trả giá đắt: xoá
// repository là mọi `FutureProvider` đọc qua nó phải hỏi lại server. Hàng chục
// lượt mạng, mỗi lượt về một lúc, mỗi lượt thay chữ một mảng màn hình. Đó đúng
// là thứ khách mô tả 10/09: "chuyển đổi rất chậm… cứ xen kẽ giữa tiếng anh và
// tiếng việt".
//
// Và nó vẫn KHÔNG đủ: chỉ widget nào tình cờ nghe một provider vừa bị xoá mới
// dựng lại. Dòng ngày ở đầu màn Hôm nay đọc `greetingNameProvider` — không nằm
// trong danh sách — nên nó ở lại tiếng Việt giữa một màn đã sang tiếng Anh.
//
// Giờ việc dựng lại do `_localeAwareBuilder` trong `app.dart` lo: đổi `Key`
// theo ngôn ngữ thì Flutter dựng lại TOÀN BỘ cây trong một khung hình, không
// cần provider nào bị xoá. Xoá cache không còn tác dụng gì ngoài việc làm chậm.
//
// ⚠ Điều kiện để giữ được như vậy: KHÔNG chốt ngôn ngữ vào lúc gọi server.
//   Model phải chở cả hai bản và chọn ở GETTER (`WrSituation.text`,
//   `MoodContent.title`, `ChoicePoolLine.text` — tất cả đều gọi `trDb`). Một
//   repository trả về chuỗi đã dịch sẵn sẽ nằm lì trong cache bằng tiếng cũ,
//   và lúc đó lại phải xoá cache — quay về đúng chỗ cũ.
//
//   Ngoại lệ hợp lệ duy nhất là chữ do AI viết (`wr_pattern_narratives`): nó
//   phải nhờ model viết lại, không getter nào dịch hộ được. Chỗ đó
//   `wrNarrativeRefreshProvider` tự `watch` ngôn ngữ.
// ---------------------------------------------------------------------------

/// Có phải phiên vừa đổi sang người khác không.
///
/// Tách riêng khỏi listener của `app.dart` để kiểm được bằng test thuần: chính
/// phép so sánh này quyết định lúc nào xoá cache, và nó phải phân biệt được ba
/// việc rất giống nhau khi nhìn từ luồng sự kiện của Supabase —
///   • đăng xuất (`next == null`) → có đổi,
///   • đăng nhập tài khoản khác → có đổi,
///   • làm mới token của cùng người đó → KHÔNG đổi, đừng đụng vào cache.
bool isUserSwitch({required String? previous, required String? next}) {
  return previous != next;
}

/// Xoá cache gắn với người dùng cũ.
///
/// Gọi khi đăng xuất và khi đăng nhập một tài khoản KHÁC. Không gọi khi phiên
/// chỉ được làm mới token (`tokenRefreshed`) — lúc đó vẫn là người cũ, xoá đi
/// chỉ khiến app tải lại toàn bộ dữ liệu vô cớ.
///
/// Nhận thẳng hàm `invalidate` (`ref.invalidate` hay `container.invalidate`)
/// thay vì nhận `WidgetRef`, để test kiểm được mà không phải dựng widget.
void resetUserScopedProviders(void Function(ProviderOrFamily) invalidate) {
  for (final provider in userScopedProviders) {
    invalidate(provider);
  }
}
