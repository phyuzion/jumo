import React from 'react';


import { MdOutlineSupervisorAccount } from 'react-icons/md';

const Login = () => {

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
      </div>
    </section>
  );
}

export default Login;

