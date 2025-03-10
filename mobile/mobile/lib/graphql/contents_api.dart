// lib/graphql/contents_api.dart

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart'; // GraphQLClientManager

class ContentsApi {
  // 쿼리
  static const _queryGetContents = r'''
    query getContents($type: Int) {
      getContents(type: $type) {
        id
        userId
        type
        title
        createdAt
        # content, comments 제외 (리스팅시 안 불러옴)
      }
    }
  ''';

  static const _queryGetSingleContent = r'''
    query getSingleContent($contentId: ID!) {
      getSingleContent(contentId: $contentId) {
        id
        userId
        type
        title
        createdAt
        content
        comments {
          userId
          comment
          createdAt
        }
      }
    }
  ''';

  // 뮤테이션
  static const _mutationCreateContent = r'''
    mutation createContent($type: Int, $title: String, $content: JSON!) {
      createContent(type: $type, title: $title, content: $content) {
        id
        userId
        type
        title
        createdAt
      }
    }
  ''';

  static const _mutationUpdateContent = r'''
    mutation updateContent($contentId: ID!, $type: Int, $title: String, $content: JSON) {
      updateContent(contentId: $contentId, type: $type, title: $title, content: $content) {
        id
        userId
        type
        title
        createdAt
        content
        comments {
          userId
          comment
          createdAt
        }
      }
    }
  ''';

  static const _mutationDeleteContent = r'''
    mutation deleteContent($contentId: ID!) {
      deleteContent(contentId: $contentId)
    }
  ''';

  static const _mutationCreateReply = r'''
    mutation createReply($contentId: ID!, $comment: String!) {
      createReply(contentId: $contentId, comment: $comment) {
        id
        comments {
          userId
          comment
          createdAt
        }
      }
    }
  ''';

  static const _mutationDeleteReply = r'''
    mutation deleteReply($contentId: ID!, $index: Int!) {
      deleteReply(contentId: $contentId, index: $index)
    }
  ''';

  /// ============ METHODS ============

  static Future<List<Map<String, dynamic>>> getContents(int type) async {
    final client = GraphQLClientManager.client;
    final opts = QueryOptions(
      document: gql(_queryGetContents),
      variables: {'type': type},
      fetchPolicy: FetchPolicy.networkOnly,
    );
    final result = await client.query(opts);
    GraphQLClientManager.handleExceptions(result);
    final data = result.data?['getContents'] as List?;
    if (data == null) return [];
    // List of Map
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<Map<String, dynamic>?> getSingleContent(
    String contentId,
  ) async {
    final client = GraphQLClientManager.client;
    final opts = QueryOptions(
      document: gql(_queryGetSingleContent),
      variables: {'contentId': contentId},
      fetchPolicy: FetchPolicy.noCache,
    );
    final result = await client.query(opts);
    GraphQLClientManager.handleExceptions(result);
    final data = result.data?['getSingleContent'] as Map<String, dynamic>?;
    return data;
  }

  static Future<Map<String, dynamic>?> createContent({
    required int type,
    required String title,
    required Map<String, dynamic> delta, // quill delta
  }) async {
    final client = GraphQLClientManager.client;
    final opts = MutationOptions(
      document: gql(_mutationCreateContent),
      variables: {'type': type, 'title': title, 'content': delta},
    );
    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result);
    final data = result.data?['createContent'] as Map<String, dynamic>?;
    return data;
  }

  static Future<Map<String, dynamic>?> updateContent({
    required String contentId,
    int? type,
    String? title,
    Map<String, dynamic>? delta,
  }) async {
    final client = GraphQLClientManager.client;
    final opts = MutationOptions(
      document: gql(_mutationUpdateContent),
      variables: {
        'contentId': contentId,
        'type': type,
        'title': title,
        'content': delta,
      },
    );
    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result);
    final data = result.data?['updateContent'] as Map<String, dynamic>?;
    return data;
  }

  static Future<bool> deleteContent(String contentId) async {
    final client = GraphQLClientManager.client;
    final opts = MutationOptions(
      document: gql(_mutationDeleteContent),
      variables: {'contentId': contentId},
    );
    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result);
    final success = result.data?['deleteContent'] as bool? ?? false;
    return success;
  }

  static Future<List<Map<String, dynamic>>> createReply({
    required String contentId,
    required String comment,
  }) async {
    final client = GraphQLClientManager.client;
    final opts = MutationOptions(
      document: gql(_mutationCreateReply),
      variables: {'contentId': contentId, 'comment': comment},
    );
    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result);

    final data = result.data?['createReply'] as Map<String, dynamic>?;
    if (data == null) return [];
    final comments = data['comments'] as List?;
    return comments?.map((e) => e as Map<String, dynamic>).toList() ?? [];
  }

  static Future<bool> deleteReply({
    required String contentId,
    required int index,
  }) async {
    final client = GraphQLClientManager.client;
    final opts = MutationOptions(
      document: gql(_mutationDeleteReply),
      variables: {'contentId': contentId, 'index': index},
    );
    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result);
    final success = result.data?['deleteReply'] as bool? ?? false;
    return success;
  }
}
