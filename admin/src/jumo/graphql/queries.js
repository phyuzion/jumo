// src/graphql/queries.js
import { gql } from '@apollo/client';

export const GET_SUMMARY = gql`
  query {
    getSummary {
      usersCount
      phoneCount
      dangerPhoneCount
    }
  }
`;

// (1) 모든 유저 조회
export const GET_ALL_USERS = gql`
  query {
    getAllUsers {
      id
      systemId
      loginId
      name
      phoneNumber
      type
      createdAt
      validUntil
    }
  }
`;

// (2) 특정 유저 + 전화번호부 기록
export const GET_USER_RECORDS = gql`
  query getUserRecords($userId: ID!) {
    getUserRecords(userId: $userId) {
      user {
        id
        systemId
        loginId
        name
        phoneNumber
        type
        createdAt
        validUntil
      }
      records {
        phoneNumber
        name
        memo
        type
        createdAt
      }
    }
  }
`;

// (A) 전화번호로 1개 문서 조회
export const GET_PHONE_NUMBER = gql`
  query getPhoneNumber($phoneNumber: String!) {
    getPhoneNumber(phoneNumber: $phoneNumber) {
      id
      phoneNumber
      type
      records {
        userName
        userType
        name
        memo
        type
        createdAt
      }
    }
  }
`;

