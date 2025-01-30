// Login.jsx
import React, { useState } from 'react';
import { useMutation } from '@apollo/client';
import { ADMIN_LOGIN } from '../graphql/queries';
import { useNavigate } from 'react-router-dom';
import { MdOutlineSupervisorAccount } from 'react-icons/md';

const Login = () => {
  const navigate = useNavigate();
  const [adminId, setAdminId] = useState('');
  const [password, setPassword] = useState('');
  const [adminLoginMutation, { loading, error }] = useMutation(ADMIN_LOGIN);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const res = await adminLoginMutation({ variables: { adminId, password } });
      const { token } = res.data.adminLogin;
      localStorage.setItem('adminToken', token);
      // login success => go summary
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
              placeholder="Admin ID"
              value={adminId}
              onChange={(e) => setAdminId(e.target.value)}
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
