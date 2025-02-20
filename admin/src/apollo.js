// src/apollo.js
import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { onError } from '@apollo/client/link/error';

// 1) HTTP Link: GraphQL 서버 URL
const httpLink = createHttpLink({
  uri: 'https://jumo-vs8e.onrender.com/graphql', // 예시
});

// 2) Auth Link: 로컬 스토리지에서 Access Token 읽어서 Authorization 헤더에 삽입
const authLink = setContext((_, { headers }) => {
  const accessToken = localStorage.getItem('adminToken');
  return {
    headers: {
      ...headers,
      Authorization: accessToken ? `Bearer ${accessToken}` : '',
    },
  };
});

// 3) Error Link: 인증 에러 시 처리
const errorLink = onError(({ graphQLErrors, networkError }) => {
  if (graphQLErrors) {
    for (let err of graphQLErrors) {
      if (err.extensions?.code === 'UNAUTHENTICATED') {
        // 만료 or 무효 토큰 → 토큰 제거 → 로그인 페이지로
        localStorage.removeItem('adminAccessToken');
        localStorage.removeItem('adminRefreshToken');
        window.location.href = '/login';
      }
    }
  }
  if (networkError && networkError.statusCode === 401) {
    localStorage.removeItem('adminAccessToken');
    localStorage.removeItem('adminRefreshToken');
    window.location.href = '/login';
  }
});

// 4) Apollo Client 생성
const client = new ApolloClient({
  link: errorLink.concat(authLink).concat(httpLink),
  cache: new InMemoryCache(),
});

export default client;
