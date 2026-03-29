import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:savemoney/core/services/gold_firebase_options.dart';
import 'package:savemoney/features/auth/data/auth_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class GoldSell {
  final String id;
  final double quantityChi;
  final double unitPrice;
  final String date;
  final String note;
  final String createdAt;

  const GoldSell({
    required this.id, required this.quantityChi,
    required this.unitPrice, required this.date,
    required this.note, required this.createdAt,
  });

  factory GoldSell.fromFirestore(DocumentSnapshot doc) {
    final j = doc.data() as Map<String, dynamic>;
    return GoldSell(
      id:          doc.id,
      quantityChi: (j['quantity_chi'] as num? ?? 0).toDouble(),
      unitPrice:   (j['unit_price']   as num? ?? 0).toDouble(),
      date:        j['date']       as String? ?? '',
      note:        j['note']       as String? ?? '',
      createdAt:   j['created_at'] as String? ?? '',
    );
  }
}

class GoldTransaction {
  final String id;
  final String type;
  final String brand;
  final String date;
  final double quantityChi;
  final double unitPrice;
  final double total;
  final String note;
  final String createdAt;
  final List<GoldSell> sells;

  const GoldTransaction({
    required this.id, required this.type, required this.brand,
    required this.date, required this.quantityChi, required this.unitPrice,
    required this.total, required this.note, required this.createdAt,
    this.sells = const [],
  });

  bool get isBuy => type == 'buy';
  double get soldChi      => sells.fold(0.0, (s, e) => s + e.quantityChi);
  double get remainingChi => quantityChi - soldChi;
  bool   get isFullySold  => remainingChi < 0.01;
  double get realizedPnl  =>
      sells.fold(0.0, (s, e) => s + (e.unitPrice - unitPrice) * e.quantityChi);

  factory GoldTransaction.fromFirestore(DocumentSnapshot doc,
      {List<GoldSell> sells = const []}) {
    final j = doc.data() as Map<String, dynamic>;
    return GoldTransaction(
      id:          doc.id,
      type:        j['type'] as String? ?? 'buy',
      brand:       j['brand'] as String? ?? '',
      date:        j['date'] as String? ?? '',
      quantityChi: (j['quantity_chi'] as num? ?? 0).toDouble(),
      unitPrice:   (j['unit_price'] as num? ?? 0).toDouble(),
      total:       (j['total'] as num? ?? 0).toDouble(),
      note:        j['note'] as String? ?? '',
      createdAt:   j['created_at'] as String? ?? '',
      sells:       sells,
    );
  }
}

class GoldSummary {
  final double totalBuyCost, totalBuyChi;
  final double totalSellRev, totalSellChi;
  final double holdingChi, holdingLuong;
  final int buyCount, sellCount;
  final double currentPrice, currentValue;
  final double netCost, profit, profitPct, avgBuyPrice;
  final double phuquyBuy, phuquySell;
  final double realizedPnl;
  final double totalSoldChiFromLots;
  final int    totalSellCountFromLots;

  const GoldSummary({
    required this.totalBuyCost, required this.totalBuyChi,
    required this.totalSellRev, required this.totalSellChi,
    required this.holdingChi, required this.holdingLuong,
    required this.buyCount, required this.sellCount,
    required this.currentPrice, required this.currentValue,
    required this.netCost, required this.profit, required this.profitPct,
    required this.avgBuyPrice,
    required this.phuquyBuy, required this.phuquySell,
    this.realizedPnl = 0,
    this.totalSoldChiFromLots = 0,
    this.totalSellCountFromLots = 0,
  });

  factory GoldSummary.compute(
    List<GoldTransaction> txs, double pqBuy, double pqSell,
  ) {
    double totalBuyCost = 0, totalBuyChi = 0;
    double totalSellRev = 0, totalSellChi = 0;
    double realizedPnl  = 0;
    double totalSoldChiFromLots = 0;
    int    totalSellCountFromLots = 0;
    int buyCount = 0, sellCount = 0;

    for (final tx in txs) {
      if (tx.isBuy) {
        totalBuyCost += tx.total;
        totalBuyChi  += tx.quantityChi;
        buyCount++;
        realizedPnl += tx.realizedPnl;
        totalSoldChiFromLots  += tx.soldChi;
        totalSellCountFromLots += tx.sells.length;
      } else {
        totalSellRev += tx.total;
        totalSellChi += tx.quantityChi;
        sellCount++;
      }
    }

    final holdingChi   = totalBuyChi - totalSellChi;
    final holdingLuong = holdingChi / 10.0;
    final avgBuyPrice  = totalBuyChi > 0 ? totalBuyCost / totalBuyChi : 0.0;
    final currentPrice = pqBuy > 0 ? pqBuy : avgBuyPrice;
    final currentValue = holdingChi * currentPrice;
    final netCost      = totalBuyCost - totalSellRev;
    final profit       = currentValue - netCost;
    final profitPct    = netCost > 0 ? profit / netCost * 100 : 0.0;

    return GoldSummary(
      totalBuyCost: totalBuyCost, totalBuyChi: totalBuyChi,
      totalSellRev: totalSellRev, totalSellChi: totalSellChi,
      holdingChi: holdingChi, holdingLuong: holdingLuong,
      buyCount: buyCount, sellCount: sellCount,
      currentPrice: currentPrice, currentValue: currentValue,
      netCost: netCost, profit: profit, profitPct: profitPct,
      avgBuyPrice: avgBuyPrice,
      phuquyBuy: pqBuy, phuquySell: pqSell,
      realizedPnl: realizedPnl,
      totalSoldChiFromLots: totalSoldChiFromLots,
      totalSellCountFromLots: totalSellCountFromLots,
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────
// Primary Firebase : savemoney-app-7292 (Google Sign-In & SaveMoney data)
// Secondary Firebase: stock-154a6       (Gold transactions data)

class GoldService {
  static const _goldAppName = 'goldApp';

  // Singleton Future - chỉ khởi tạo 1 lần dù gọi song song
  static Future<FirebaseApp>? _initFuture;

  Future<FirebaseApp> _initGoldApp() =>
      _initFuture ??= _doInitGoldApp();

  static Future<FirebaseApp> _doInitGoldApp() async {
    try {
      return Firebase.app(_goldAppName);
    } catch (_) {
      // Chọn options đúng theo platform
      final options = defaultTargetPlatform == TargetPlatform.iOS
          ? GoldFirebaseOptions.ios   // iOS options (thêm sau khi register app trên Firebase)
          : GoldFirebaseOptions.android;
      return Firebase.initializeApp(
        name: _goldAppName,
        options: options,
      );
    }
  }

  // Firestore của secondary app
  Future<FirebaseFirestore> get _db async {
    final app = await _initGoldApp();
    return FirebaseFirestore.instanceFor(app: app);
  }

  // UID của user trong stock-154a6 chứa data vàng
  static const _goldOwnerUid = '7LCSCGd8SjZ0ZiS89VsvUFOLGg43';

  /// Lấy UID để truy cập gold data, ưu tiên hardcoded UID nếu các tầng auth kia trả về UID trống data
  Future<String?> get _uid async {
    final app = await _initGoldApp();
    final auth = FirebaseAuth.instanceFor(app: app);

    // ── Tầng 1: Đã auth rồi ────────────────────────────────────────────────
    if (auth.currentUser != null) {
      // Nếu UID hiện tại khác UID chứa data vàng, dùng UID chứa data vàng
      return _goldOwnerUid;
    }

    // ── Tầng 2: Google credential chain ────────────────────────────────────
    OAuthCredential? credential = AuthService.lastGoogleCredential;

    if (credential == null) {
      try {
        var gUser = AuthService.googleSignIn.currentUser
                 ?? await AuthService.googleSignIn.signInSilently();
        if (gUser != null) {
          final googleAuth = await gUser.authentication;
          credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken:     googleAuth.idToken,
          );
          AuthService.lastGoogleCredential = credential;
        }
      } catch (_) {}
    }

    if (credential != null) {
      try {
        await auth.signInWithCredential(credential);
        return _goldOwnerUid; // Trả về hardcoded UID dù login = credential nào
      } catch (_) {}
    }

    // ── Tầng 3: Fallback – anonymous auth ────────
    try {
      await auth.signInAnonymously();
      return _goldOwnerUid;
    } catch (_) {}
    
    return _goldOwnerUid;
  }

  Future<CollectionReference<Map<String, dynamic>>?> get _col async {
    final uid = await _uid;
    if (uid == null) return null;
    final db = await _db;
    return db.collection('users').doc(uid).collection('gold_transactions');
  }

  /// Debug: lấy UID đang dùng để verify (xóa sau khi debug xong)
  Future<String?> debugGetUid() => _uid;

  CollectionReference<Map<String, dynamic>>? _sellsColSync(
      CollectionReference<Map<String, dynamic>> col, String buyId) {
    return col.doc(buyId).collection('sells')
        as CollectionReference<Map<String, dynamic>>;
  }

  // ─── Price scraping ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPhuquyPrice() async {
    try {
      final res = await http.get(
        Uri.parse('http://banggia.phuquygroup.vn'),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return {'buy': 0.0, 'sell': 0.0};
      final body = res.body;

      double buy = 0, sell = 0;
      final rowRe = RegExp(r'<tr[^>]*>.*?Nhẫn\s*tr.*?Ph.*?Qu.*?</tr>',
          caseSensitive: false, dotAll: true);
      final rowMatch = rowRe.firstMatch(body);
      if (rowMatch != null) {
        final row = rowMatch.group(0)!;
        final numRe = RegExp(r'(\d{1,3}(?:[.,]\d{3})+)');
        final nums = numRe.allMatches(row)
            .map((m) => double.tryParse(
                m.group(1)!.replaceAll(',', '').replaceAll('.', '')) ?? 0)
            .where((n) => n > 1_000_000)
            .toList();
        if (nums.length >= 2) { buy = nums[0]; sell = nums[1]; }
        else if (nums.length == 1) { buy = sell = nums[0]; }
      }

      return {'buy': buy, 'sell': sell};
    } catch (_) {
      return {'buy': 0.0, 'sell': 0.0};
    }
  }

  // ─── CRUD ──────────────────────────────────────────────────────────────────

  Future<List<GoldTransaction>> getTransactions({String? type}) async {
    final col = await _col;
    if (col == null) return [];
    final snap = await col.orderBy('date', descending: true).get();

    final futures = snap.docs.map((doc) async {
      final txType = (doc.data()['type'] as String?) ?? 'buy';
      List<GoldSell> sells = const [];
      if (txType == 'buy') {
        final sellSnap = await col.doc(doc.id)
            .collection('sells').orderBy('date').get();
        sells = sellSnap.docs.map(GoldSell.fromFirestore).toList();
      }
      return GoldTransaction.fromFirestore(doc, sells: sells);
    });

    final all = await Future.wait(futures);
    if (type != null) return all.where((t) => t.type == type).toList();
    return all;
  }

  Future<GoldSummary> getSummary() async {
    final txs = await getTransactions();
    final pq  = await getPhuquyPrice();
    return GoldSummary.compute(
      txs,
      (pq['buy']  as num? ?? 0).toDouble(),
      (pq['sell'] as num? ?? 0).toDouble(),
    );
  }

  Future<bool> addTransaction({
    required String type, required String brand,
    required String date, required double quantityChi,
    required double unitPrice, String note = '',
  }) async {
    final col = await _col;
    if (col == null) return false;
    await col.add({
      'type': type, 'brand': brand, 'date': date,
      'quantity_chi': quantityChi, 'unit_price': unitPrice,
      'total': quantityChi * unitPrice, 'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  Future<bool> updateTransaction({
    required String id, required String type, required String brand,
    required String date, required double quantityChi,
    required double unitPrice, String note = '',
  }) async {
    final col = await _col;
    if (col == null) return false;
    await col.doc(id).update({
      'type': type, 'brand': brand, 'date': date,
      'quantity_chi': quantityChi, 'unit_price': unitPrice,
      'total': quantityChi * unitPrice, 'note': note,
    });
    return true;
  }

  Future<bool> addSell({
    required String buyId, required double quantityChi,
    required double unitPrice, required String date, String note = '',
  }) async {
    final col = await _col;
    if (col == null) return false;
    try {
      await col.doc(buyId).collection('sells').add({
        'quantity_chi': quantityChi, 'unit_price': unitPrice,
        'date': date, 'note': note,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deleteTransaction(String id) async {
    final col = await _col;
    if (col == null) return false;
    await col.doc(id).delete();
    return true;
  }

  Future<bool> deleteSell(String buyId, String sellId) async {
    final col = await _col;
    if (col == null) return false;
    try {
      await col.doc(buyId).collection('sells').doc(sellId).delete();
      return true;
    } catch (_) { return false; }
  }
}
