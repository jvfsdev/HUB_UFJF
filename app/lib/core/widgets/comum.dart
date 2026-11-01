import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/usuario.dart';
import '../errors.dart';

/// Conteúdo com largura máxima e espaçamento responsivo.
class Pagina extends StatelessWidget {
  const Pagina({
    super.key,
    required this.children,
    this.maxWidth = 1080,
    this.padding,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return ListView(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: mobile ? 16 : 32,
            vertical: mobile ? 16 : 24,
          ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cabeçalho de página com título, subtítulo e ação opcional.
class CabecalhoPagina extends StatelessWidget {
  const CabecalhoPagina({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acao,
    this.icone,
  });

  final String titulo;
  final String? subtitulo;
  final Widget? acao;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[
                CircleAvatar(
                  radius: 22,
                  backgroundColor: t.colorScheme.primaryContainer,
                  child: Icon(icone, color: t.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: t.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitulo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitulo!,
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          ?acao,
        ],
      ),
    );
  }
}

/// Estado vazio com convite à ação (ex.: RF08 fluxo alternativo 2, RF07 fila vazia).
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    this.mensagem,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String? mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icone, size: 56, color: t.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (mensagem != null) ...[
            const SizedBox(height: 6),
            Text(
              mensagem!,
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (acao != null) ...[const SizedBox(height: 20), acao!],
        ],
      ),
    );
  }
}

/// Renderiza um AsyncValue com carregamento e erro padronizados (RNF11).
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.carregando,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? carregando;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      data: data,
      loading: () =>
          carregando ??
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
      error: (e, st) {
        LogService.registrar(e, st, nivel: 'consulta');
        return EstadoVazio(
          icone: Icons.cloud_off_outlined,
          titulo: 'Não foi possível carregar',
          mensagem: mensagemErro(e),
        );
      },
    );
  }
}

class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({super.key, required this.nome, this.raio = 18});

  final String nome;
  final double raio;

  static const _cores = [
    Color(0xFF0B3D91),
    Color(0xFF00796B),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
    Color(0xFFEF6C00),
    Color(0xFF2E7D32),
    Color(0xFF283593),
    Color(0xFF4E342E),
  ];

  @override
  Widget build(BuildContext context) {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final iniciais = partes.isEmpty
        ? '?'
        : partes.length == 1
        ? partes.first[0].toUpperCase()
        : (partes.first[0] + partes.last[0]).toUpperCase();
    final cor = _cores[nome.hashCode.abs() % _cores.length];
    return CircleAvatar(
      radius: raio,
      backgroundColor: cor,
      child: Text(
        iniciais,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: raio * 0.75,
        ),
      ),
    );
  }
}

class SeloPerfil extends StatelessWidget {
  const SeloPerfil(this.perfil, {super.key});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final (cor, icone) = switch (perfil) {
      Perfil.estudante => (const Color(0xFF0B3D91), Icons.school),
      Perfil.geral => (const Color(0xFF00796B), Icons.badge_outlined),
      Perfil.externo => (const Color(0xFFEF6C00), Icons.explore_outlined),
      Perfil.admin => (const Color(0xFFC62828), Icons.shield_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: cor),
          const SizedBox(width: 4),
          Text(
            perfil.label,
            style: TextStyle(
              color: cor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class Estrelas extends StatelessWidget {
  const Estrelas({
    super.key,
    required this.nota,
    this.tamanho = 16,
    this.onChanged,
  });

  final double nota;
  final double tamanho;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: MouseRegion(
              cursor: onChanged == null
                  ? MouseCursor.defer
                  : SystemMouseCursors.click,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: onChanged == null ? 0 : 4,
                ),
                child: Icon(
                  nota >= i
                      ? Icons.star_rounded
                      : (nota >= i - 0.5
                            ? Icons.star_half_rounded
                            : Icons.star_outline_rounded),
                  size: tamanho,
                  color: const Color(0xFFF2A900),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip(this.texto, {super.key, this.cor, this.icone});

  final String texto;
  final Color? cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 14, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de status para o autor (ex.: publicação aguardando aprovação — RF07).
class AvisoStatus extends StatelessWidget {
  const AvisoStatus({
    super.key,
    required this.icone,
    required this.texto,
    this.cor,
  });

  final IconData icone;
  final String texto;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? const Color(0xFFEF6C00);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icone, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: c, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

String tempoRelativo(DateTime data) => timeago.format(data, locale: 'pt_BR');
String dataFormatada(DateTime data) =>
    DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(data);
String dataHoraFormatada(DateTime data) =>
    DateFormat("EEE, d 'de' MMM 'às' HH:mm", 'pt_BR').format(data);
String moeda(double valor) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(valor);

/// Contador de caracteres para campos com limite (RF04: 5000, RF05: 1000).
Widget? contadorCaracteres(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) {
  if (maxLength == null || currentLength < maxLength * 0.8) return null;
  return Text(
    '$currentLength / $maxLength',
    style: TextStyle(
      color: currentLength >= maxLength
          ? Theme.of(context).colorScheme.error
          : null,
      fontSize: 12,
    ),
  );
}
