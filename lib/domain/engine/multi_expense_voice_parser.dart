import '../models/expense_draft.dart';
import '../models/trip_member.dart';
import 'advanced_voice_expense_parser.dart';

/// Production-grade Multi-Expense Voice Parser.
/// Extracts single or multiple discrete expense drafts from compound English, Hindi,
/// and Hinglish spoken voice transcripts with zero paid API overhead and 100% integer paise precision.
///
/// Delegates to [AdvancedVoiceExpenseParser] for advanced Indian NLP, spoken numerals,
/// and context-aware member resolution.
class MultiExpenseVoiceParser {
  const MultiExpenseVoiceParser._();

  /// Main entry point: Parses [transcript] into a list of [ExpenseDraft]s.
  static List<ExpenseDraft> parse(
    String transcript, {
    List<TripMember> members = const [],
    String? currentUserId,
    String tripCurrency = 'INR',
  }) {
    return AdvancedVoiceExpenseParser.parse(
      transcript,
      members: members,
      currentUserId: currentUserId,
      tripCurrency: tripCurrency,
    );
  }
}
