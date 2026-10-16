enum QuestionCategory {
  literatura,
  geografia,
  historia,
  matematicas,
  lenguaje,
  ciencias,
  sociales,
}

enum QuestionDifficulty { basico, intermedio, dificil }

enum QuestionSource { unmsm, uni, utp, pucp, original }

enum QuestionExam {
  uniAah20262,
  unmsm20262e,
  ocadUni20172,
}

enum QuestionSubject {
  matematicas,
  logica,
  lenguaje,
  literatura,
  historia,
  geografia,
  economia,
  filosofia,
  psicologia,
  fisica,
  quimica,
  biologia,
  ingles,
  actualidad,
  civica,
}

extension QuestionCategoryX on QuestionCategory {
  String get id => name;

  String get label => switch (this) {
        QuestionCategory.literatura => 'Literatura',
        QuestionCategory.geografia => 'Geografía',
        QuestionCategory.historia => 'Historia',
        QuestionCategory.matematicas => 'Matemáticas',
        QuestionCategory.lenguaje => 'Lenguaje',
        QuestionCategory.ciencias => 'Ciencias',
        QuestionCategory.sociales => 'Sociales',
      };

  String get emoji => switch (this) {
        QuestionCategory.literatura => '📖',
        QuestionCategory.geografia => '🌎',
        QuestionCategory.historia => '🏛️',
        QuestionCategory.matematicas => '➗',
        QuestionCategory.lenguaje => '✍️',
        QuestionCategory.ciencias => '🔬',
        QuestionCategory.sociales => '🧠',
      };
}

extension QuestionExamX on QuestionExam {
  String get label => switch (this) {
        QuestionExam.uniAah20262 => 'UNI 2026-II · AHH',
        QuestionExam.unmsm20262e => 'UNMSM 2026-II · Área E',
        QuestionExam.ocadUni20172 => 'OCAD-UNI 2017-2',
      };

  String get toDb => switch (this) {
        QuestionExam.uniAah20262 => 'uni_aah_2026_2',
        QuestionExam.unmsm20262e => 'unmsm_2026_2_e',
        QuestionExam.ocadUni20172 => 'ocad_uni_2017_2',
      };
}

extension QuestionSubjectX on QuestionSubject {
  String get label => switch (this) {
        QuestionSubject.matematicas => 'Matemáticas',
        QuestionSubject.logica => 'Lógica',
        QuestionSubject.lenguaje => 'Lenguaje',
        QuestionSubject.literatura => 'Literatura',
        QuestionSubject.historia => 'Historia',
        QuestionSubject.geografia => 'Geografía',
        QuestionSubject.economia => 'Economía',
        QuestionSubject.filosofia => 'Filosofía',
        QuestionSubject.psicologia => 'Psicología',
        QuestionSubject.fisica => 'Física',
        QuestionSubject.quimica => 'Química',
        QuestionSubject.biologia => 'Biología',
        QuestionSubject.ingles => 'Inglés',
        QuestionSubject.actualidad => 'Actualidad',
        QuestionSubject.civica => 'Cívica',
      };

  String get emoji => switch (this) {
        QuestionSubject.matematicas => '➗',
        QuestionSubject.logica => '🧩',
        QuestionSubject.lenguaje => '✍️',
        QuestionSubject.literatura => '📖',
        QuestionSubject.historia => '🏛️',
        QuestionSubject.geografia => '🌎',
        QuestionSubject.economia => '📈',
        QuestionSubject.filosofia => '💭',
        QuestionSubject.psicologia => '🧠',
        QuestionSubject.fisica => '⚛️',
        QuestionSubject.quimica => '🧪',
        QuestionSubject.biologia => '🧬',
        QuestionSubject.ingles => '🇬🇧',
        QuestionSubject.actualidad => '📰',
        QuestionSubject.civica => '🗳️',
      };
}

extension QuestionDifficultyX on QuestionDifficulty {
  String get label => switch (this) {
        QuestionDifficulty.basico => 'Básico',
        QuestionDifficulty.intermedio => 'Intermedio',
        QuestionDifficulty.dificil => 'Difícil',
      };
}

extension QuestionSourceX on QuestionSource {
  String get label => switch (this) {
        QuestionSource.unmsm => 'San Marcos',
        QuestionSource.uni => 'UNI',
        QuestionSource.utp => 'UTP',
        QuestionSource.pucp => 'Católica',
        QuestionSource.original => 'Colibrí',
      };

  String get fullName => switch (this) {
        QuestionSource.unmsm => 'UNMSM · San Marcos',
        QuestionSource.uni => 'UNI · Ingeniería',
        QuestionSource.utp => 'UTP · Tecnológica',
        QuestionSource.pucp => 'PUCP · Católica',
        QuestionSource.original => 'Pregunta original Colibrí',
      };

  bool get isTough =>
      this == QuestionSource.unmsm || this == QuestionSource.uni;
}

QuestionCategory parseCategory(String value) {
  return QuestionCategory.values.firstWhere(
    (c) => c.name == value,
    orElse: () => throw FormatException('Categoría desconocida: $value'),
  );
}

QuestionDifficulty parseDifficulty(String value) {
  return QuestionDifficulty.values.firstWhere(
    (d) => d.name == value,
    orElse: () => throw FormatException('Dificultad desconocida: $value'),
  );
}

QuestionSource parseSource(String value) {
  return QuestionSource.values.firstWhere(
    (s) => s.name == value,
    orElse: () => throw FormatException('Fuente desconocida: $value'),
  );
}

QuestionExam parseExam(String value) {
  return QuestionExam.values.firstWhere(
    (e) => e.toDb == value,
    orElse: () => throw FormatException('Prueba desconocida: $value'),
  );
}

QuestionSubject parseSubject(String value) {
  return QuestionSubject.values.firstWhere(
    (s) => s.name == value,
    orElse: () => throw FormatException('Asignatura desconocida: $value'),
  );
}

class Question {
  const Question({
    required this.id,
    required this.category,
    required this.topic,
    required this.source,
    required this.difficulty,
    required this.statement,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.optionAnalysis,
    this.reference,
    this.exam,
    this.subject,
    this.image,
    this.optionImages,
  });

  final String id;
  final QuestionCategory category;
  final String topic;
  final QuestionSource source;
  final QuestionDifficulty difficulty;
  final String statement;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final List<String> optionAnalysis;
  final String? reference;
  final QuestionExam? exam;
  final QuestionSubject? subject;
  final String? image;
  final List<String?>? optionImages;

  String get correctAnswer => options[correctIndex];

  bool get hasImage => image != null || optionImages != null;

  bool get hasSupport => statement.contains('\n\n');

  String get supportText {
    if (!hasSupport) return '';
    return statement.substring(0, statement.lastIndexOf('\n\n'));
  }

  String get questionText {
    if (!hasSupport) return statement;
    return statement.substring(statement.lastIndexOf('\n\n') + 2);
  }

  bool isCorrect(int? selected) => selected == correctIndex;

  factory Question.fromJson(Map<String, dynamic> json) {
    final options =
        (json['opciones'] as List).map((e) => e as String).toList();
    final correct = json['correcta'] as int;
    final analysis =
        (json['analisis'] as List).map((e) => e as String).toList();

    if (options.length < 4 || options.length > 5) {
      throw FormatException(
          'La pregunta ${json['id']} debe tener 4 u 5 opciones');
    }
    if (correct < 0 || correct >= options.length) {
      throw FormatException('Índice correcto inválido en ${json['id']}');
    }
    if (analysis.length != options.length) {
      throw FormatException(
          'Análisis incompleto en ${json['id']} (se esperaban '
          '${options.length}, hay ${analysis.length})');
    }

    final optionImagesJson = json['imagenes_opciones'] as List<dynamic>?;
    final optionImages = optionImagesJson
        ?.map((e) => e as String?)
        .toList(growable: false);
    if (optionImages != null && optionImages.length != options.length) {
      throw FormatException(
          'imagenes_opciones incompleto en ${json['id']} (se esperaban '
          '${options.length}, hay ${optionImages.length})');
    }

    return Question(
      id: json['id'] as String,
      category: parseCategory(json['categoria'] as String),
      topic: json['tema'] as String,
      source: parseSource(json['fuente'] as String),
      difficulty: parseDifficulty(json['dificultad'] as String),
      statement: json['enunciado'] as String,
      options: options,
      correctIndex: correct,
      explanation: json['explicacion'] as String,
      optionAnalysis: analysis,
      reference: json['referencia'] as String?,
      exam: json['prueba'] == null ? null : parseExam(json['prueba'] as String),
      subject: json['asignatura'] == null
          ? null
          : parseSubject(json['asignatura'] as String),
      image: json['imagen'] as String?,
      optionImages: optionImages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoria': category.name,
        'tema': topic,
        'fuente': source.name,
        'dificultad': difficulty.name,
        'enunciado': statement,
        'opciones': options,
        'correcta': correctIndex,
        'explicacion': explanation,
        'analisis': optionAnalysis,
        if (reference != null) 'referencia': reference,
        if (exam != null) 'prueba': exam!.toDb,
        if (subject != null) 'asignatura': subject!.name,
        if (image != null) 'imagen': image,
        if (optionImages != null) 'imagenes_opciones': optionImages,
      };
}
