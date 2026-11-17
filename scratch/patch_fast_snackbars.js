const fs = require('fs');

const files = [
  'lib/screens/artisan_detail_screen.dart',
  'lib/screens/home_screen.dart',
  'lib/screens/login_screen.dart',
  'lib/screens/market_detail_screens.dart',
  'lib/screens/market_screen.dart',
  'lib/screens/payment_screens.dart',
  'lib/screens/register_screen.dart',
  'lib/screens/shorts_screen.dart',
  'lib/widgets/add_post_bottom_sheet.dart',
  'lib/widgets/location_map_picker.dart',
];

function patchSnackBars(content) {
  content = content.replace(/ScaffoldMessenger\.of\(([^)]+)\)\.showSnackBar\(/g, 'ScaffoldMessenger.of($1)..clearSnackBars()..showSnackBar(');

  let out = '';
  let i = 0;
  while (i < content.length) {
    const idx = content.indexOf('SnackBar(', i);
    if (idx === -1) {
      out += content.slice(i);
      break;
    }

    if (idx > 0 && /[a-zA-Z0-9_]/.test(content[idx - 1])) {
      out += content.slice(i, idx + 9);
      i = idx + 9;
      continue;
    }

    const beforeSlice = content.slice(Math.max(0, idx - 6), idx);
    const isConst = beforeSlice === 'const ';

    let depth = 1;
    let j = idx + 9;
    let inSingle = false, inDouble = false, escape = false;
    while (j < content.length && depth > 0) {
      const ch = content[j];
      if (escape) {
        escape = false;
      } else if (ch === '\\') {
        escape = true;
      } else if (ch === "'" && !inDouble) {
        inSingle = !inSingle;
      } else if (ch === '"' && !inSingle) {
        inDouble = !inDouble;
      } else if (!inSingle && !inDouble) {
        if (ch === '(') depth++;
        else if (ch === ')') depth--;
      }
      j++;
    }

    const inner = content.slice(idx + 9, j - 1);
    if (/\bduration\s*:/.test(inner)) {
      out += content.slice(i, j);
    } else {
      const durText = isConst
        ? 'duration: Duration(milliseconds: 1300), '
        : 'duration: const Duration(milliseconds: 1300), ';
      out += content.slice(i, idx + 9) + durText + inner + ')';
    }
    i = j;
  }
  return out;
}

for (const file of files) {
  const before = fs.readFileSync(file, 'utf8');
  const after = patchSnackBars(before);
  if (after !== before) {
    fs.writeFileSync(file, after, 'utf8');
    console.log('Updated SnackBars cleanly in:', file);
  }
}

let artisan = fs.readFileSync('lib/screens/artisan_detail_screen.dart', 'utf8');

const oldDeleteStart = '    if (confirmed != true) return;\n\n    try {';
const newDeleteStart = `    if (confirmed != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Rəyiniz silindi'), backgroundColor: Colors.orange),
      );
    }

    try {`;

if (artisan.includes(oldDeleteStart)) {
  artisan = artisan.replace(oldDeleteStart, newDeleteStart);
  artisan = artisan.replace(
`      await _recalculateArtisanRating(artisanUid);

      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Rəyiniz silindi'), backgroundColor: Colors.orange),
        );
      }`,
    `      await _recalculateArtisanRating(artisanUid);`
  );
  console.log('Made _deleteReview instant');
}

const oldAddNav = `                Navigator.pop(ctx);

                try {
                  final reviewsRef = FirebaseFirestore.instance`;

const newAddNav = `                Navigator.pop(ctx);

                if (mounted) {
                  setState(() => _selectedTabIndex = 1);
                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 1300),
                      content: Text(isEdit ? 'Rəyiniz yeniləndi!' : 'Rəyiniz əlavə edildi!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                try {
                  final reviewsRef = FirebaseFirestore.instance`;

if (artisan.includes(oldAddNav)) {
  artisan = artisan.replace(oldAddNav, newAddNav);
  artisan = artisan.replace(
`                  await _recalculateArtisanRating(artisanUid);

                  if (mounted) {
                    setState(() => _selectedTabIndex = 1);
                    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                      SnackBar(duration: const Duration(milliseconds: 1300), 
                        content: Text(isEdit ? 'Rəyiniz uğurla yeniləndi!' : 'Rəyiniz uğurla əlavə edildi! Təşəkkür edirik.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }`,
    `                  await _recalculateArtisanRating(artisanUid);`
  );
  console.log('Made _showAddReviewDialog instant');
}

fs.writeFileSync('lib/screens/artisan_detail_screen.dart', artisan, 'utf8');
