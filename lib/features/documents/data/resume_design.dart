import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The PDF layouts a resume can be exported in.
enum ResumeDesign {
  classic('Classic', 'Clean and timeless, with teal section lines'),
  modern('Modern', 'A dark name banner and a sidebar for skills'),
  compact('Compact', 'Tighter spacing to fit more on one page'),
  plain('ATS-friendly', 'Plain and single-column, easiest for screening software');

  const ResumeDesign(this.label, this.description);

  final String label;
  final String description;
}

/// Remembers the chosen [ResumeDesign] on the device.
class ResumeDesignStore {
  ResumeDesignStore({SharedPreferencesAsync? prefs}) : _injectedPrefs = prefs;

  final SharedPreferencesAsync? _injectedPrefs;
  late final _prefs = _injectedPrefs ?? SharedPreferencesAsync();

  static const _key = 'resume_design';

  Future<ResumeDesign> load() async {
    try {
      final name = await _prefs.getString(_key);
      return ResumeDesign.values.firstWhere(
        (d) => d.name == name,
        orElse: () => ResumeDesign.classic,
      );
    } catch (e) {
      debugPrint('Resume design unreadable: $e');
      return ResumeDesign.classic;
    }
  }

  Future<void> save(ResumeDesign design) => _prefs.setString(_key, design.name);
}
