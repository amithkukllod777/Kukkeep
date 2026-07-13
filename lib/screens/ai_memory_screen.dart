import 'package:flutter/material.dart';
import '../api.dart';
import '../note_colors.dart';

/// AI Memory — "Ask your notes". Sends a natural-language question to the
/// backend which answers using only the user's KukKeep notes.
class AiMemoryScreen extends StatefulWidget {
  const AiMemoryScreen({super.key});
  @override
  State<AiMemoryScreen> createState() => _AiMemoryScreenState();
}

class _AiMemoryScreenState extends State<AiMemoryScreen> {
  final _q = TextEditingController();
  bool _loading = false;
  String? _answer;
  String? _error;

  Future<void> _ask() async {
    final q = _q.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _answer = null; _error = null; });
    try {
      final a = await Api.instance.askNotes(q);
      if (!mounted) return;
      setState(() => _answer = a.isEmpty ? "Sorry, I couldn't find that in your notes." : a);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Memory'), backgroundColor: kBrand, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 4),
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [kBrand, kBrandViolet]), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('Ask anything about your notes — KukKeep finds the answer.', style: TextStyle(fontSize: 13, color: Colors.grey))),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _q,
            minLines: 1, maxLines: 3,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _ask(),
            decoration: InputDecoration(
              hintText: 'e.g. "payment wala note dikhao"',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.send, color: kBrand), onPressed: _ask),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: kBrand))),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_answer != null)
            Expanded(child: SingleChildScrollView(child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_answer!, style: const TextStyle(fontSize: 14, height: 1.4)),
            ))),
          if (_answer == null && !_loading && _error == null)
            const Padding(padding: EdgeInsets.only(top: 24), child: Text(
              'Tip: try "last week ka supplier note" or "voice note jisme packaging ki baat thi".',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))),
        ]),
      ),
    );
  }
}
