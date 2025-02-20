import { gql } from '@apollo/client';


// (1) Admin 로그인
export const ADMIN_LOGIN = gql`
  mutation adminLogin($username: String!, $password: String!) {
    adminLogin(username: $username, password: $password) {
      accessToken
      refreshToken
    }
  }
`;

export const CREATE_USER = gql`
  mutation createUser($phone: String!, $name: String, $memo: String, $validUntil: String) {
    createUser(phone: $phone, name: $name, memo: $memo, validUntil: $validUntil) {
      _id
      userId
      phone
      name
      memo
      validUntil
    }
  }
`;

export const UPDATE_USER = gql`
  mutation updateUser($userId: String!, $phone: String, $name: String, $memo: String, $validUntil: String) {
    updateUser(userId: $userId, phone: $phone, name: $name, memo: $memo, validUntil: $validUntil) {
      _id
      userId
      phone
      name
      memo
      validUntil
    }
  }
`;
