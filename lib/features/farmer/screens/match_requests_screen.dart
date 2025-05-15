import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting

// Assuming these are in your project structure and correctly defined
import '../../../core/models/match_suggestion.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';

class MatchRequestsScreen extends StatefulWidget {
  const MatchRequestsScreen({super.key});

  // If you navigate to this screen using named routes, define routeName:
  // static const String routeName = '/match-requests';

  @override
  State<MatchRequestsScreen> createState() => _MatchRequestsScreenState();
}

class _MatchRequestsScreenState extends State<MatchRequestsScreen> {
  late final FirestoreService _firestoreService;
  late final String? _currentUserId;

  @override
  void initState() {
    super.initState();
    // It's generally safer to access providers in initState if listen:false,
    // or in didChangeDependencies if listen:true or for things that might change.
    // For services that don't change per build, initState is fine.
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    _currentUserId = authService.currentFirebaseUser?.uid;
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
  }

  Future<void> _updateSuggestionStatus(MatchSuggestion suggestion, MatchStatus newStatus) async {
    if (suggestion.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Suggestion ID is missing.')),
      );
      return;
    }
    try {
      await _firestoreService.updateMatchSuggestionStatus(suggestion.id!, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suggestion status updated to ${newStatus.displayName}.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating suggestion: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Match Suggestions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4A2E2B), // Consistent with dashboard
      ),
      body: _currentUserId == null
          ? const Center(child: Text("User not authenticated."))
          : StreamBuilder<List<MatchSuggestion>>(
        stream: _firestoreService.getFarmerMatchSuggestions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error fetching match suggestions: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No new match suggestions at the moment.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final suggestions = snapshot.data!;
          // Filter for suggestions that require farmer action
          final actionableSuggestions = suggestions.where((s) =>
          s.status == MatchStatus.pending_farmer_approval ||
              s.status == MatchStatus.accepted_by_buyer
          ).toList();

          final otherSuggestions = suggestions.where((s) =>
          s.status != MatchStatus.pending_farmer_approval &&
              s.status != MatchStatus.accepted_by_buyer
          ).toList();


          if (actionableSuggestions.isEmpty && otherSuggestions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No match suggestions available.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              if (actionableSuggestions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                  child: Text("Action Required (${actionableSuggestions.length})", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
                ...actionableSuggestions.map((suggestion) =>
                    _MatchSuggestionCard(
                      suggestion: suggestion,
                      onAccept: () {
                        MatchStatus nextStatus;
                        if (suggestion.status == MatchStatus.pending_farmer_approval) {
                          nextStatus = MatchStatus.accepted_by_farmer;
                        } else if (suggestion.status == MatchStatus.accepted_by_buyer) {
                          nextStatus = MatchStatus.confirmed;
                        } else {
                          return; // Should not happen based on filter
                        }
                        _updateSuggestionStatus(suggestion, nextStatus);
                      },
                      onReject: () {
                        _updateSuggestionStatus(suggestion, MatchStatus.rejected_by_farmer);
                      },
                    )
                ).toList(),
                const Divider(height: 30, thickness: 1),
              ],
              if (otherSuggestions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                  child: Text("Other Suggestions (${otherSuggestions.length})", style: Theme.of(context).textTheme.titleMedium),
                ),
                ...otherSuggestions.map((suggestion) =>
                    _MatchSuggestionCard(suggestion: suggestion) // No actions for these
                ).toList(),
              ]
            ],
          );
        },
      ),
    );
  }
}

class _MatchSuggestionCard extends StatelessWidget {
  final MatchSuggestion suggestion;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _MatchSuggestionCard({
    required this.suggestion,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActionable = suggestion.status == MatchStatus.pending_farmer_approval ||
        suggestion.status == MatchStatus.accepted_by_buyer;
    final DateFormat dateFormat = DateFormat('MMM d, yyyy \'at\' hh:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    suggestion.produceName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(suggestion.status.displayName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: _getStatusColor(suggestion.status),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('From Buyer: ${suggestion.buyerName ?? 'N/A'}', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.shopping_basket_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${suggestion.suggestedQuantity.toStringAsFixed(1)} ${suggestion.unit}'),
                const SizedBox(width: 12),
                const Icon(Icons.sell_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(suggestion.suggestedPricePerUnit != null
                    ? '${suggestion.currency ?? ''} ${suggestion.suggestedPricePerUnit!.toStringAsFixed(2)} per ${suggestion.unit}'
                    : 'Price not set'),
              ],
            ),
            const SizedBox(height: 12),
            Text('AI Match Score: ${(suggestion.aiMatchScore * 100).toStringAsFixed(0)}%', style: TextStyle(color: _getScoreColor(suggestion.aiMatchScore), fontWeight: FontWeight.w600)),
            Text('Rationale: ${suggestion.aiMatchRationale}', style: Theme.of(context).textTheme.bodySmall),
            if (suggestion.systemNotes != null && suggestion.systemNotes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('System Notes: ${suggestion.systemNotes}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 8),
            Text('Suggested: ${dateFormat.format(suggestion.createdAt)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
            if (suggestion.expiresAt != null)
              Text('Expires: ${dateFormat.format(suggestion.expiresAt!)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange[700])),

            if (isActionable && onAccept != null && onReject != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
                    onPressed: onReject,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onAccept,
                  ),
                ],
              ),
            ],
            if (suggestion.status == MatchStatus.order_created && suggestion.createdOrderId != null) ...[
              const SizedBox(height: 12),
              Text('Order Created: ID ${suggestion.createdOrderId}', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500)),
            ]
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(MatchStatus status) {
    switch (status) {
      case MatchStatus.pending_farmer_approval:
      case MatchStatus.pending_buyer_approval:
        return Colors.orange.shade600;
      case MatchStatus.accepted_by_farmer:
      case MatchStatus.accepted_by_buyer:
        return Colors.blue.shade600;
      case MatchStatus.confirmed:
      case MatchStatus.order_created:
        return Colors.green.shade600;
      case MatchStatus.rejected_by_farmer:
      case MatchStatus.rejected_by_buyer:
      case MatchStatus.cancelled:
        return Colors.red.shade600;
      case MatchStatus.expired:
        return Colors.grey.shade600;
      default:
        return Colors.grey;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 0.75) return Colors.green.shade700;
    if (score >= 0.5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}
