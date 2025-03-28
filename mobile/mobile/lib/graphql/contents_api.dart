import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart'; // GraphQLClientManager

class ContentsApi {
  // =================== QUERIES ===================

  static const _queryGetContents = r'''
    query getContents($type: String) {
      getContents(type: $type) {
        id
        userId
        userName
        userRegion
        type
        title
        createdAt
      }
    }
  ''';

  static const _queryGetSingleContent = r'''
    query getSingleContent($contentId: ID!) {
      getSingleContent(contentId: $contentId) {
        id
        userId
        userName
        userRegion
        type
        title
        createdAt
        content
        comments {
          userId
          userName
          userRegion
          comment
          createdAt
        }
      }
    }
  ''';

  // =================== MUTATIONS ===================

  static const _mutationCreateContent = r'''
    mutation createContent($type: String, $title: String, $content: JSON!) {
      createContent(type: $type, title: $title, content: $content) {
        id
        userId
        userName
        userRegion
        type
        title
        createdAt
      }
    }
  ''';

  static const _mutationUpdateContent = r'''
    mutation updateContent($contentId: ID!, $type: String, $title: String, $content: JSON) {
      updateContent(contentId: $contentId, type: $type, title: $title, content: $content) {
        id
        userId
        userName
        userRegion
        type
        title
        createdAt
        content
        comments {
          userId
          userName
          userRegion
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
        userId
        userName
        userRegion
        type
        title
        createdAt
        content
        comments {
          userId
          userName
          userRegion
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

  // =================== METHODS ===================

  /// 글 목록 조회
  static Future<List<Map<String, dynamic>>> getContents(String type) async {
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

  /// 단일 글 + 댓글 상세 조회
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

  /// 글 생성 (Quill Delta 형태 content)
  static Future<Map<String, dynamic>?> createContent({
    required String type,
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

  /// 글 수정
  static Future<Map<String, dynamic>?> updateContent({
    required String contentId,
    String? type,
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

  /// 글 삭제
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

  /// 댓글 생성
  static Future<Map<String, dynamic>?> createReply({
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
    return data;
  }

  /// 댓글 삭제
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
