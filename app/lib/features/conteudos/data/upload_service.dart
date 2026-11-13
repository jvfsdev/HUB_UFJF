import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/firebase.dart';
import '../../../models/publicacao.dart';

/// RF11 — formatos e limite de tamanho aceitos (as storage.rules repetem a mesma validação).
class FormatoArquivo {
  const FormatoArquivo(this.extensao, this.contentType, this.tipo);
  final String extensao;
  final String contentType;

  /// `imagem`, `pdf` ou `video`.
  final String tipo;

  static const todos = [
    FormatoArquivo('pdf', 'application/pdf', 'pdf'),
    FormatoArquivo('png', 'image/png', 'imagem'),
    FormatoArquivo('jpg', 'image/jpeg', 'imagem'),
    FormatoArquivo('jpeg', 'image/jpeg', 'imagem'),
    FormatoArquivo('webp', 'image/webp', 'imagem'),
    FormatoArquivo('mp4', 'video/mp4', 'video'),
  ];

  static FormatoArquivo? porNome(String nome) {
    final ext = nome.split('.').last.toLowerCase();
    return todos.where((f) => f.extensao == ext).firstOrNull;
  }
}

class UploadService {
  UploadService(this._storage);

  final FirebaseStorage _storage;
  static const tamanhoMaximo = 50 * 1024 * 1024;

  /// Valida formato e tamanho (fluxos alternativos 1 e 2 do RF11).
  static FormatoArquivo validar(
    String nome,
    int tamanho, {
    Set<String>? tiposPermitidos,
  }) {
    final formato = FormatoArquivo.porNome(nome);
    final permitidos = tiposPermitidos ?? const {'pdf', 'imagem', 'video'};
    if (formato == null || !permitidos.contains(formato.tipo)) {
      final lista = FormatoArquivo.todos
          .where((f) => permitidos.contains(f.tipo) && f.extensao != 'jpeg')
          .map((f) => f.extensao.toUpperCase())
          .join(', ');
      throw AppException('Formato não suportado. Envie um arquivo $lista.');
    }
    if (tamanho > tamanhoMaximo) {
      final mb = (tamanho / (1024 * 1024)).toStringAsFixed(1);
      throw AppException(
        'O arquivo tem $mb MB e o limite é 50 MB. Envie um arquivo menor.',
      );
    }
    return formato;
  }

  /// Envia o arquivo para `uploads/{uid}/{area}/` e devolve o progresso e, ao final, o anexo.
  Stream<(double, Anexo?)> enviar({
    required String uid,
    required String area,
    required String nome,
    required Uint8List bytes,
    Set<String>? tiposPermitidos,
  }) async* {
    final formato = validar(
      nome,
      bytes.length,
      tiposPermitidos: tiposPermitidos,
    );
    final limpo = nome.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ref = _storage.ref(
      'uploads/$uid/$area/${DateTime.now().millisecondsSinceEpoch}_$limpo',
    );
    final task = ref.putData(
      bytes,
      SettableMetadata(contentType: formato.contentType),
    );
    await for (final s in task.snapshotEvents) {
      if (s.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        yield (
          1,
          Anexo(
            nome: nome,
            url: url,
            tipo: formato.tipo,
            tamanho: bytes.length,
          ),
        );
        return;
      }
      if (s.state == TaskState.error) {
        throw const AppException('Falha no envio do arquivo. Tente novamente.');
      }
      yield (s.totalBytes == 0 ? 0 : s.bytesTransferred / s.totalBytes, null);
    }
  }
}

final uploadServiceProvider = Provider<UploadService>(
  (ref) => UploadService(ref.watch(storageProvider)),
);
