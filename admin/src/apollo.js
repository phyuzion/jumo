// src/apollo.js (수정)
import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { onError } from '@apollo/client/link/error';

const httpLink = createHttpLink({
  uri: 'https://jumo-vs8e.onrender.com/graphql',
});

// Auth Link
const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('adminToken');
  return {
    headers: {
      ...headers,
      Authorization: token ? `Bearer ${token}` : ""
    }
  };
});

// Error Link
const errorLink = onError(({ graphQLErrors, networkError }) => {
  if (graphQLErrors) {
    for (let err of graphQLErrors) {
      // 예: 토큰 만료 시 서버가 "UNAUTHENTICATED" 라는 code를 내려준다거나,
      // 또는 401 등으로 처리
      if (err.extensions?.code === "UNAUTHENTICATED") {
        // 로그아웃 처리
        localStorage.removeItem('adminToken');
        window.location.href = '/login';
      }
    }
  }
  if (networkError && networkError.statusCode === 401) {
    // 네트워크 레벨 401
    localStorage.removeItem('adminToken');
    window.location.href = '/login';
  }
});

const client = new ApolloClient({
  link: errorLink.concat(authLink).concat(httpLink),
  cache: new InMemoryCache()
});

export default client;
