import 'package:content_srd52/content_srd52.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

/// Le pack SRD 5.2 embarqué, chargé une fois au démarrage.
final srdPackProvider = FutureProvider<ContentPack>((ref) => loadSrd52Pack());
