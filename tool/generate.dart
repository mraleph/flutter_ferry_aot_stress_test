// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as p;

void execute(String command, List<String> args) {
  print('running $command ${args.join(' ')}');
  final sw = Stopwatch()..start();
  final result = Process.runSync(command, args);
  sw.stop();
  print(result.stdout);
  print(result.stderr);
  if (result.exitCode != 0) {
    print('... FAILED!');
  } else {
    print('... OK!');
  }
  print('... TOOK ${sw.elapsedMilliseconds}ms');
}

void main(List<String> args) {
  if (args.length != 1) {
    print('Usage: generate.dart <number-of-copies>');
    return;
  }

  // Clear existing files.
  final graphqlDir = Directory('lib/graphql');
  if (graphqlDir.existsSync()) {
    graphqlDir.deleteSync(recursive: true);
  }
  graphqlDir.createSync();

  // Create schema.graphql

  const int unionSize = 10;
  const int numFields = 10;
  final types = List.generate(unionSize, (i) => 'U$i');
  final members = {
    'id': 'ID!',
    for (var i = 0; i < numFields; i++) 'f$i': 'String',
  };

  String makeUnion(List<String> types) => types.join(' | ');
  String makeType(String name, Map<String, String> members) {
    final memberDeclarations =
        members.entries.map((e) => '  ${e.key}: ${e.value}').join('\n');
    return '''
type $name {
$memberDeclarations
}''';
  }

  final allTypes =
      List.generate(unionSize, (i) => makeType('U$i', members)).join('\n\n');

  File(p.join(graphqlDir.path, 'schema.graphql')).writeAsStringSync("""
schema {
  query: Q
}

type Q {
  q(): R!
}

type R {
  r: [U!]!
}

union U = ${makeUnion(types)}

$allTypes

""");

  final int numCopies = int.parse(args[0]);

  String makeCopy(int idx) {
    String requestForUnionMember(String typeName, Iterable<String> fields) {
      return '''
... on $typeName {
  ${fields.join('\n  ')}
}''';
    }

    return '''
query q$idx () {
  q() {
    __typename
    r {
      __typename
      ${List.generate(unionSize, (i) => requestForUnionMember('U$i', members.keys)).join('\n')}
    }
  }
}''';
  }

  for (var i = 0; i < numCopies; i++) {
    File(p.join(graphqlDir.path, 'q$i.graphql')).writeAsStringSync(makeCopy(i));
  }
}
