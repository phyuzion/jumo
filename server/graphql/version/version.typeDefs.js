// graphql/version/version.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  # 파일 업로드를 위한 스칼라
  scalar Upload

  type Query {
    """
    현재 서버에 저장된 APK 버전 정보를 문자열로 반환
    """
    checkAPKVersion: String
  }

  type Mutation {
    """
    APK 파일 업로드
    - version: 새 버전 문자열
    - file: 실제 APK 파일
    """
    uploadAPK(version: String!, file: Upload!): Boolean
  }
`;
