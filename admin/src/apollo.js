// src/apollo.js
import { ApolloClient, InMemoryCache, createHttpLink, from } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { TokenRefreshLink } from 'apollo-link-token-refresh';
import { jwtDecode } from 'jwt-decode';
import { onError } from '@apollo/client/link/error';
import { createUploadLink } from 'apollo-upload-client';

// TokenRefreshLink
const tokenRefreshLink = new TokenRefreshLink({
  isTokenValidOrUndefined: async () => {
    const token = localStorage.getItem('adminToken');
    if (!token) return true; // not logged in
    try {
      const { exp } = jwtDecode(token);
      if (!exp) return true;
      const now = Date.now() / 1000;
      return exp > now; // exp가 현재보다 크면 유효
    } catch (err) {
      return false;
    }
  },
  fetchAccessToken: async () => {
    const refreshToken = localStorage.getItem('adminRefreshToken');
    if (!refreshToken) {
      return Promise.reject('No refresh token');
    }
    // refreshToken Mutation
    const res = await fetch('https://jumo-vs8e.onrender.com/graphql', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query: `
          mutation refreshToken($refreshToken: String!) {
            refreshToken(refreshToken:$refreshToken) {
              accessToken
              refreshToken
            }
          }
        `,
        variables: { refreshToken },
      }),
    });
    return await res.json();
  },
  handleFetch: (response) => {
    const newAcc = response.data.refreshToken.accessToken;
    const newRef = response.data.refreshToken.refreshToken;
    localStorage.setItem('adminToken', newAcc);
    localStorage.setItem('adminRefreshToken', newRef);
  },
  handleError: (err) => {
    console.error('Failed to refresh token:', err);
    localStorage.removeItem('adminToken');
    localStorage.removeItem('adminRefreshToken');
    window.location.href = '/login';
  },
});

// Auth Link
const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('adminToken');
  return {
    headers: {
      ...headers,
      Authorization: token ? `Bearer ${token}` : '',
    },
  };
});

// Error Link
const errorLink = onError(({ graphQLErrors, networkError }) => {
  // Refresh Token도 만료 or 기타?
  if (graphQLErrors) {
    for (let err of graphQLErrors) {
      if (err.extensions?.code === 'UNAUTHENTICATED') {
        console.log('UNAUTHENTICATED -> forced logout');
        localStorage.removeItem('adminToken');
        localStorage.removeItem('adminRefreshToken');
        window.location.href = '/login';
      }
    }
  }
  if (networkError && networkError.statusCode === 401) {
    console.log('401 -> forced logout');
    localStorage.removeItem('adminToken');
    localStorage.removeItem('adminRefreshToken');
    window.location.href = '/login';
  }
});


// ==============================
// 4) Upload Link (replaces createHttpLink)
// ==============================
const uploadLink = createUploadLink({
  uri: 'https://jumo-vs8e.onrender.com/graphql',
  // fetchOptions or credentials if needed
});



const client = new ApolloClient({
  link: from([
    tokenRefreshLink,
    errorLink,
    authLink,
    uploadLink,
  ]),
  cache: new InMemoryCache(),
});

export default client;
