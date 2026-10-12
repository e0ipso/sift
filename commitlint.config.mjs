const aiTools = [
  'aider',
  'amp',
  'anthropic',
  'chatgpt',
  'claude',
  'codex',
  'copilot',
  'cursor',
  'devin',
  'gemini',
  'jules',
  'openai',
  'opencode',
  'qwen',
  'windsurf',
].join('|');

// Unicode-aware word boundaries, so "Ampère" or "OpenCoder" don't match.
const tool = `(?<![\\p{L}\\p{N}])(?:${aiTools})(?![\\p{L}\\p{N}])`;

const forbiddenPatterns = [
  // Any co-author, human or not.
  /^Co-authored-by:.*/im,
  // Made-with: Cursor, Assisted-by: Claude:claude-opus-5-5, ...
  new RegExp(
    `^(?:Assisted-by|Generated-by|Made-with|Signed-off-by):.*${tool}`,
    'imu',
  ),
  // Tool-specific trailers: Copilot-Session: ..., Amp-Thread: ...
  new RegExp(`^${tool}-[\\w-]+:`, 'imu'),
  // 🤖 Generated with [Claude Code](https://claude.com/claude-code)
  new RegExp(`(?:Generated|Made) (?:with|by|using)\\b.*${tool}`, 'iu'),
];

// Sift ticket IDs point at a private tracker. Built from parts so this file
// doesn't contain one.
const ticketId = new RegExp(['DASH', '-', '\\d{4}'].join(''));

export default {
  extends: ['@commitlint/config-conventional'],
  plugins: [
    {
      rules: {
        'no-ai-generated': parsed => {
          const message = parsed.raw;

          for (const pattern of forbiddenPatterns) {
            const match = message.match(pattern);
            if (match) {
              return [
                false,
                `Commit message contains forbidden AI-generated content: "${match[0]}"`,
              ];
            }
          }

          return [true, ''];
        },
        'no-sift-ticket-ids': parsed => {
          const match = parsed.raw.match(ticketId);
          if (match) {
            return [
              false,
              `Commit message cites a sift ticket ID, which is private: "${match[0]}"`,
            ];
          }

          return [true, ''];
        },
      },
    },
  ],
  rules: {
    'no-ai-generated': [2, 'always'],
    'no-sift-ticket-ids': [2, 'always'],
  },
};
