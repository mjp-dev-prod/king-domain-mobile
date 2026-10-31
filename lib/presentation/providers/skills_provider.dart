import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../data/models/skill.dart';

/// The skill catalogue from the server. Screens that need it show their own
/// loading and retry states; there is no bundled copy, so the app never shows
/// a skill list the server doesn't have.
final skillCatalogProvider = FutureProvider<SkillCatalog>((ref) async {
  final json = await ApiClient.instance.get('/skills') as Map<String, dynamic>;
  return SkillCatalog.fromJson(json);
});
