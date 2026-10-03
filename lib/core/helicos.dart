// Deux hélicos fixes. Seul endroit où vivent id et libellé : les renommer ne
// touche pas aux données (seul `id` est stocké dans Firestore).
enum Helico {
  h1('H1', 'Hélico H1'),
  h2('H2', 'Hélico H2');

  const Helico(this.id, this.label);

  final String id;
  final String label;

  static Helico? fromId(String? id) {
    for (final h in values) {
      if (h.id == id) return h;
    }
    return null;
  }
}
