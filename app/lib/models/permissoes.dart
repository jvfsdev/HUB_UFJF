import 'package:flutter/material.dart';

import 'usuario.dart';

/// Áreas da plataforma controladas pela matriz de permissões (RF13).
enum Area {
  foruns('Fóruns', Icons.forum_outlined),
  anuncios('Anúncios', Icons.storefront_outlined),
  eventos('Eventos e Projetos', Icons.event_outlined),
  materiais('Materiais de Estudo', Icons.menu_book_outlined),
  grade('Grade Curricular', Icons.account_tree_outlined),
  avaliacoes('Avaliações', Icons.star_outline),
  orientacoes('Orientações', Icons.support_agent_outlined);

  const Area(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum Acao {
  ler('Ler'),
  publicar('Publicar');

  const Acao(this.label);
  final String label;
}

/// Matriz perfil × área × ação, persistida em `config/permissoes`.
/// O administrador tem acesso total e não aparece na matriz.
class Permissoes {
  const Permissoes(this.perfis);

  final Map<Perfil, Map<Area, Set<Acao>>> perfis;

  static const editaveis = [Perfil.estudante, Perfil.geral, Perfil.externo];

  bool pode(Perfil perfil, Area area, Acao acao) {
    if (perfil == Perfil.admin) return true;
    return perfis[perfil]?[area]?.contains(acao) ?? false;
  }

  Permissoes alternar(Perfil perfil, Area area, Acao acao) {
    final copia = {
      for (final e in perfis.entries)
        e.key: {
          for (final a in e.value.entries) a.key: {...a.value},
        },
    };
    final atual = copia
        .putIfAbsent(perfil, () => {})
        .putIfAbsent(area, () => {});
    atual.contains(acao) ? atual.remove(acao) : atual.add(acao);
    return Permissoes(copia);
  }

  /// RF13 (fluxo alternativo 1) — configurações que contradizem os requisitos.
  List<String> conflitos() {
    final lista = <String>[];
    for (final perfil in editaveis) {
      for (final area in Area.values) {
        if (pode(perfil, area, Acao.publicar) &&
            !pode(perfil, area, Acao.ler)) {
          lista.add(
            '${perfil.label} pode publicar em "${area.label}" sem poder ler essa área.',
          );
        }
      }
    }
    for (final area in Area.values) {
      if (area != Area.orientacoes && pode(Perfil.externo, area, Acao.ler)) {
        lista.add(
          'Comunidade Externa só pode acessar Orientações (RF14), mas tem acesso a "${area.label}".',
        );
      }
    }
    for (final perfil in [Perfil.geral, Perfil.externo]) {
      if (pode(perfil, Area.avaliacoes, Acao.publicar)) {
        lista.add(
          'Apenas Estudantes podem avaliar (RF05), mas ${perfil.label} tem permissão de publicar avaliações.',
        );
      }
    }
    if (!pode(Perfil.estudante, Area.orientacoes, Acao.ler)) {
      lista.add(
        'Estudantes precisam ler Orientações para responder aos futuros calouros (RF14).',
      );
    }
    return lista;
  }

  factory Permissoes.fromMap(Map<String, dynamic>? data) {
    final perfisMap = (data?['perfis'] as Map<String, dynamic>?) ?? const {};
    if (perfisMap.isEmpty) return Permissoes.padrao;
    return Permissoes({
      for (final perfil in editaveis)
        perfil: {
          for (final area in Area.values)
            area: {
              for (final acao in Acao.values)
                if ((perfisMap[perfil.name]?[area.name]?[acao.name]) == true)
                  acao,
            },
        },
    });
  }

  Map<String, dynamic> toMap() => {
    'perfis': {
      for (final perfil in editaveis)
        perfil.name: {
          for (final area in Area.values)
            area.name: {
              for (final acao in Acao.values)
                acao.name: pode(perfil, area, acao),
            },
        },
    },
  };

  bool igual(Permissoes outra) {
    for (final perfil in editaveis) {
      for (final area in Area.values) {
        for (final acao in Acao.values) {
          if (pode(perfil, area, acao) != outra.pode(perfil, area, acao)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  static final padrao = Permissoes({
    Perfil.estudante: {
      for (final a in Area.values) a: {Acao.ler, Acao.publicar},
    },
    Perfil.geral: {
      Area.foruns: {Acao.ler, Acao.publicar},
      Area.anuncios: {Acao.ler, Acao.publicar},
      Area.eventos: {Acao.ler, Acao.publicar},
      Area.materiais: {Acao.ler, Acao.publicar},
      Area.grade: {Acao.ler},
      Area.avaliacoes: {Acao.ler},
      Area.orientacoes: {},
    },
    Perfil.externo: {
      for (final a in Area.values)
        a: a == Area.orientacoes ? {Acao.ler, Acao.publicar} : <Acao>{},
    },
  });
}
