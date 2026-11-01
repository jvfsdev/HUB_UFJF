import 'package:flutter/material.dart';

class Categoria {
  const Categoria(this.id, this.label, this.icone, this.cor);
  final String id;
  final String label;
  final IconData icone;
  final Color cor;
}

/// RF06 — categorias de anúncio.
const categoriasAnuncio = [
  Categoria(
    'republica',
    'Repúblicas e moradia',
    Icons.home_work_outlined,
    Color(0xFF00796B),
  ),
  Categoria(
    'apostilas',
    'Apostilas e livros',
    Icons.menu_book_outlined,
    Color(0xFF283593),
  ),
  Categoria(
    'jalecos',
    'Jalecos e EPIs',
    Icons.checkroom_outlined,
    Color(0xFF6A1B9A),
  ),
  Categoria(
    'materiais',
    'Materiais acadêmicos',
    Icons.architecture_outlined,
    Color(0xFFEF6C00),
  ),
];

/// RF09 — categorias de eventos e projetos.
const categoriasEvento = [
  Categoria(
    'extensao',
    'Projeto de extensão',
    Icons.diversity_3_outlined,
    Color(0xFF2E7D32),
  ),
  Categoria(
    'roda_conversa',
    'Roda de conversa',
    Icons.forum_outlined,
    Color(0xFF6A1B9A),
  ),
  Categoria(
    'grupo_interesse',
    'Grupo de interesse',
    Icons.groups_outlined,
    Color(0xFF0B3D91),
  ),
  Categoria(
    'iniciativa_social',
    'Iniciativa social',
    Icons.volunteer_activism_outlined,
    Color(0xFFC62828),
  ),
  Categoria(
    'academico',
    'Evento acadêmico',
    Icons.school_outlined,
    Color(0xFFEF6C00),
  ),
];

/// Tipos de projeto e grupo estudantil (RF05, RF09).
const categoriasProjeto = [
  Categoria(
    'ensino',
    'Grupo de educação tutorial',
    Icons.school_outlined,
    Color(0xFF0B3D91),
  ),
  Categoria(
    'pesquisa',
    'Laboratório de pesquisa',
    Icons.science_outlined,
    Color(0xFF00838F),
  ),
  Categoria(
    'extensao',
    'Projeto de extensão',
    Icons.diversity_3_outlined,
    Color(0xFF2E7D32),
  ),
  Categoria(
    'empresa_junior',
    'Empresa júnior',
    Icons.business_center_outlined,
    Color(0xFF283593),
  ),
  Categoria(
    'competicao',
    'Equipe de competição',
    Icons.emoji_events_outlined,
    Color(0xFFEF6C00),
  ),
  Categoria(
    'iniciativa_social',
    'Iniciativa social',
    Icons.volunteer_activism_outlined,
    Color(0xFFC62828),
  ),
  Categoria(
    'grupo_interesse',
    'Grupo estudantil',
    Icons.groups_outlined,
    Color(0xFF6A1B9A),
  ),
];

Categoria categoriaPorId(List<Categoria> lista, String? id) =>
    lista.where((c) => c.id == id).firstOrNull ?? lista.first;
