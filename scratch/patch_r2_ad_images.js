const fs = require('fs');

// 1. Patch market_screen.dart
let marketContent = fs.readFileSync('lib/screens/market_screen.dart', 'utf8');

if (!marketContent.includes("import '../services/r2_image_upload_service.dart';")) {
  marketContent = "import '../services/r2_image_upload_service.dart';\n" + marketContent;
  console.log('Added R2ImageUploadService import to market_screen.dart');
}

// In showStoreFormSheet: add rawPickedLogoBytes and upload to R2
const storePickerTarget = `                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setModalState(() => logoBase64 = base64Encode(bytes));
                          }`;

const storePickerReplacement = `                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            rawPickedLogoBytes = bytes;
                            setModalState(() => logoBase64 = base64Encode(bytes));
                          }`;

if (marketContent.includes(storePickerTarget)) {
  marketContent = marketContent.replace(
    'String? logoBase64 = existingStore?[\'logoBase64\']?.toString();',
    'String? logoBase64 = existingStore?[\'logoBase64\']?.toString();\n    String? logoUrl = existingStore?[\'logoUrl\']?.toString();\n    Uint8List? rawPickedLogoBytes;'
  );
  marketContent = marketContent.replace(storePickerTarget, storePickerReplacement);

  const storeSaveTarget = `                              final payload = {
                                'listingType': 'store',`;

  const storeSaveReplacement = `                              if (rawPickedLogoBytes != null) {
                                final uploadedLogo = await R2ImageUploadService.uploadImage(rawPickedLogoBytes!, folder: 'store_logos');
                                if (uploadedLogo != null) logoUrl = uploadedLogo;
                              }

                              final payload = {
                                'listingType': 'store',
                                'logoUrl': logoUrl,`;

  marketContent = marketContent.replace(storeSaveTarget, storeSaveReplacement);
  console.log('Updated showStoreFormSheet for R2 upload');
}

// In showProductFormSheet: add rawPickedImageBytes and upload to R2
const prodPickerTarget = `                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setModalState(() => imageBase64 = base64Encode(bytes));
                          }`;

const prodPickerReplacement = `                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            rawPickedImageBytes = bytes;
                            setModalState(() => imageBase64 = base64Encode(bytes));
                          }`;

if (marketContent.includes(prodPickerTarget)) {
  marketContent = marketContent.replace(
    'String? imageBase64 = existingProduct?[\'imageBase64\']?.toString();',
    'String? imageBase64 = existingProduct?[\'imageBase64\']?.toString();\n    String? imageUrl = existingProduct?[\'imageUrl\']?.toString();\n    Uint8List? rawPickedImageBytes;'
  );
  marketContent = marketContent.replace(prodPickerTarget, prodPickerReplacement);

  const prodSaveTarget = `                              final payload = {
                                'listingType': 'product',`;

  const prodSaveReplacement = `                              if (rawPickedImageBytes != null) {
                                final uploadedImg = await R2ImageUploadService.uploadImage(rawPickedImageBytes!, folder: 'ads');
                                if (uploadedImg != null) imageUrl = uploadedImg;
                              }

                              final payload = {
                                'listingType': 'product',
                                'imageUrl': imageUrl,`;

  marketContent = marketContent.replace(prodSaveTarget, prodSaveReplacement);
  console.log('Updated showProductFormSheet for R2 upload');
}

// In _buildProductVisual: support imageUrl
const visualTarget = `  Widget _buildProductVisual(Map<String, dynamic> prod) {
    final Uint8List? imgBytes = _decodeB64(prod['imageBase64']?.toString());
    if (imgBytes != null) {
      return Image.memory(imgBytes, fit: BoxFit.cover, gaplessPlayback: true);
    }`;

const visualReplacement = `  Widget _buildProductVisual(Map<String, dynamic> prod) {
    final String? imgUrl = prod['imageUrl']?.toString();
    if (imgUrl != null && imgUrl.startsWith('http')) {
      return Image.network(
        imgUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          final Uint8List? imgBytes = _decodeB64(prod['imageBase64']?.toString());
          if (imgBytes != null) return Image.memory(imgBytes, fit: BoxFit.cover, gaplessPlayback: true);
          return const SizedBox.shrink();
        },
      );
    }
    final Uint8List? imgBytes = _decodeB64(prod['imageBase64']?.toString());
    if (imgBytes != null) {
      return Image.memory(imgBytes, fit: BoxFit.cover, gaplessPlayback: true);
    }`;

if (marketContent.includes(visualTarget)) {
  marketContent = marketContent.replace(visualTarget, visualReplacement);
  console.log('Updated _buildProductVisual for R2 imageUrl');
}

// In firestoreProducts mapping in _buildProductsTab: map imageUrl
marketContent = marketContent.replace(
  "'imageBase64': data['imageBase64'] ?? '',",
  "'imageBase64': data['imageBase64'] ?? '',\n                  'imageUrl': data['imageUrl'] ?? '',"
);

fs.writeFileSync('lib/screens/market_screen.dart', marketContent, 'utf8');
console.log('Saved market_screen.dart');

// 2. Patch market_detail_screens.dart
let detailContent = fs.readFileSync('lib/screens/market_detail_screens.dart', 'utf8');

// In ProductDetailScreen banner:
const detailImgTarget = `                  if (imgBytes != null)
                    Image.memory(imgBytes, fit: BoxFit.cover)
                  else`;

const detailImgReplacement = `                  if ((_prod['imageUrl'] ?? '').toString().startsWith('http'))
                    Image.network(
                      _prod['imageUrl'].toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => imgBytes != null
                          ? Image.memory(imgBytes, fit: BoxFit.cover)
                          : const SizedBox.shrink(),
                    )
                  else if (imgBytes != null)
                    Image.memory(imgBytes, fit: BoxFit.cover)
                  else`;

if (detailContent.includes(detailImgTarget)) {
  detailContent = detailContent.replace(detailImgTarget, detailImgReplacement);
  console.log('Updated ProductDetailScreen banner for R2 imageUrl');
}

// In StoreDetailScreen logo:
const storeLogoTarget = `                      CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: logoBytes != null
                            ? ClipOval(child: Image.memory(logoBytes, fit: BoxFit.cover, width: 68, height: 68))
                            : const Icon(Icons.storefront_rounded, color: Color(0xFF1769D2), size: 36),
                      ),`;

const storeLogoReplacement = `                      CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: (store['logoUrl'] ?? '').toString().startsWith('http')
                            ? ClipOval(
                                child: Image.network(
                                  store['logoUrl'].toString(),
                                  fit: BoxFit.cover,
                                  width: 68,
                                  height: 68,
                                  errorBuilder: (_, __, ___) => logoBytes != null
                                      ? Image.memory(logoBytes, fit: BoxFit.cover, width: 68, height: 68)
                                      : const Icon(Icons.storefront_rounded, color: Color(0xFF1769D2), size: 36),
                                ),
                              )
                            : (logoBytes != null
                                ? ClipOval(child: Image.memory(logoBytes, fit: BoxFit.cover, width: 68, height: 68))
                                : const Icon(Icons.storefront_rounded, color: Color(0xFF1769D2), size: 36)),
                      ),`;

if (detailContent.includes(storeLogoTarget)) {
  detailContent = detailContent.replace(storeLogoTarget, storeLogoReplacement);
  console.log('Updated StoreDetailScreen logo for R2 logoUrl');
}

// In StoreDetailScreen product grid:
const gridImgTarget = `                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                      child: pBytes != null
                                          ? Image.memory(pBytes, fit: BoxFit.cover)
                                          : Container(
                                              color: const Color(0xFFEFF6FF),
                                              child: const Center(
                                                child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 36),
                                              ),
                                            ),
                                    ),`;

const gridImgReplacement = `                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                      child: (p['imageUrl'] ?? '').toString().startsWith('http')
                                          ? Image.network(
                                              p['imageUrl'].toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => pBytes != null
                                                  ? Image.memory(pBytes, fit: BoxFit.cover)
                                                  : Container(
                                                      color: const Color(0xFFEFF6FF),
                                                      child: const Center(
                                                        child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 36),
                                                      ),
                                                    ),
                                            )
                                          : (pBytes != null
                                              ? Image.memory(pBytes, fit: BoxFit.cover)
                                              : Container(
                                                  color: const Color(0xFFEFF6FF),
                                                  child: const Center(
                                                    child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 36),
                                                  ),
                                                )),
                                    ),`;

if (detailContent.includes(gridImgTarget)) {
  detailContent = detailContent.replace(gridImgTarget, gridImgReplacement);
  console.log('Updated StoreDetailScreen grid image for R2 imageUrl');
}

fs.writeFileSync('lib/screens/market_detail_screens.dart', detailContent, 'utf8');
console.log('Saved market_detail_screens.dart');
