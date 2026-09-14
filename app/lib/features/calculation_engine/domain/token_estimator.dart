/// Character-count → token heuristic. Deliberately avoids shipping a tokenizer
/// (BPE vocab files are several MB and would need to run on every keystroke).
///
/// Only a character COUNT ever reaches this class — never the text itself.
library;

class TokenEstimator {
  const TokenEstimator({this.charsPerToken = 4.0});
  final double charsPerToken;

  int estimate(int charCount) {
    if (charCount <= 0) return 0;
    return (charCount / charsPerToken).ceil();
  }
}
