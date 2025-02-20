// src/pages/Login.jsx
import React, { useState } from 'react';
import { useMutation } from '@apollo/client';
import { ADMIN_LOGIN } from '../graphql/mutations';
import { useNavigate } from 'react-router-dom';
import { MdOutlineSupervisorAccount } from 'react-icons/md';

const Login = () => {
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  // 1) useMutation 훅
  const [adminLoginMutation, { loading, error }] = useMutation(ADMIN_LOGIN);

  // 2) 로그인 버튼 클릭
  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      // adminLogin(username, password) 호출
      const res = await adminLoginMutation({ variables: { username, password } });
      // 서버 응답: { data: { adminLogin: { accessToken, refreshToken } } }
      const { accessToken, refreshToken } = res.data.adminLogin;

      // 3) 로컬 스토리지에 저장
      localStorage.setItem('adminAccessToken', accessToken);
      localStorage.setItem('adminRefreshToken', refreshToken);

      alert('로그인 성공');
      // 4) 로그인 성공 후 페이지 이동
      navigate('/summary');
    } catch (err) {
      alert('로그인 실패: ' + err.message);
    }
  };

  return (
    <section className="mt-24 md:mt-2 mx-7">
      <div className='flex flex-wrap lg:flex-nowrap justify-center flex-col items-center'>

        <div className="mt-6">
          <button
            type='button'
            style={{ color: '#03C9D7', backgroundColor: '#E5FAFB' }}
            className="text-2xl opacity-0.9 rounded-full p-4 hover:drop-shadow-xl"
          >
            <MdOutlineSupervisorAccount />
          </button>
        </div>

        <div className="mt-6">
          <form onSubmit={handleSubmit} className="flex flex-col gap-2">
            <input
              type="text"
              placeholder="Admin Username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="p-2 border rounded"
            />
            <input
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="p-2 border rounded"
            />
            <button
              type="submit"
              disabled={loading}
              className="bg-blue-500 text-white px-4 py-2 rounded"
            >
              {loading ? 'Logging in...' : 'Login'}
            </button>
            {error && <p className="text-red-500">{error.message}</p>}
          </form>
        </div>
      </div>
    </section>
  );
};

export default Login;
