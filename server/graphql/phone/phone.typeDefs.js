// graphql/phone/phone.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  type Record {
    # userId: ID # 스키마에서 제외
    userName: String
    userType: String
    name: String
    memo: String
    type: Int
    createdAt: String
    phoneNumber: String # phoneNumber 필드 추가 (Nullable 또는 Non-nullable?)
  }

  type PhoneNumber {
    id: ID!
    phoneNumber: String!
    type: Int
    blockCount: Int!
    records: [Record!]!
    todayRecords: [TodayRecord]
  }

  type BlockNumber {
    phoneNumber: String!
    blockCount: Int!
  }

  # 업서트 입력
  input PhoneRecordInput {
    phoneNumber: String!
    # 관리자 등이 특정 사용자를 지정할 수 있도록 userName, userType 유지 (Nullable)
    userName: String
    userType: String
    name: String! # 이름 필수
    memo: String # Nullable
    type: Int    # Nullable
    createdAt: String! # 시각 필수
  }

  # UserPhoneRecord 타입 제거 (필요 시 다른 곳에서 사용하면 유지)
  # type UserPhoneRecord { ... }

  extend type Query {
    """
    특정 전화번호의 상세 정보 조회 (전체 구조)
    isRequested: true면 통화 제한 체크
    """
    getPhoneNumber(phoneNumber: String!, isRequested: Boolean): PhoneNumber
    getPhoneNumbersByType(type: Int!): [PhoneNumber!]!
    # getMyRecords 제거
    # getMyRecords: [UserPhoneRecord!]!
    getBlockNumbers(count: Int!): [BlockNumber!]!

    """
    특정 전화번호에 대한 나의 기록(메모, 타입) 조회
    """
    getPhoneRecord(phoneNumber: String!): Record # 개별 레코드 조회 추가
  }

  extend type Mutation {
    """
    여러 번호(레코드) 업서트
    """
    upsertPhoneRecords(records: [PhoneRecordInput!]!): Boolean
  }
`;
