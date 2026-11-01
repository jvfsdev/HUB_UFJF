/// Normalização usada na busca (RF15). Espelha `gerarKeywords` em functions/src/common.ts:
/// a function grava os prefixos de cada palavra e o app consulta com o termo normalizado.
String normalizar(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final c in texto.toLowerCase().split('')) {
    final i = de.indexOf(c);
    buffer.write(i >= 0 ? para[i] : c);
  }
  return buffer.toString();
}

/// Termo de consulta: a palavra mais longa digitada, limitada a 15 letras (tamanho
/// máximo dos prefixos indexados). Retorna `null` se não houver palavra com 3+ letras.
String? termoDeBusca(String consulta) {
  final palavras =
      normalizar(consulta)
          .split(RegExp(r'[^a-z0-9]+'))
          .where((p) => p.length >= 3)
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  if (palavras.isEmpty) return null;
  final p = palavras.first;
  return p.length > 15 ? p.substring(0, 15) : p;
}

/// Filtro local complementar: todas as palavras da consulta devem aparecer no texto.
bool correspondeATodas(String consulta, String texto) {
  final alvo = normalizar(texto);
  return normalizar(consulta)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((p) => p.length >= 3)
      .every(alvo.contains);
}
