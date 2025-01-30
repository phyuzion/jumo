import React from 'react';

import { earningData, } from '../data/dummy';
import { useStateContext } from '../contexts/ContextProvider';


const Summary = () => {

  return (
    <section className="mt-24 md:mt-2 mx-7">
      <div className='flex flex-wrap lg:flex-nowrap justify-center flex-col items-center'>
        
        <div className="flex m-3 flex-wrap justify-center gap-5 items-center">
          {earningData.map((item) => (
            <div
              key={item.title}
              className='bg-white dark:text-gray-200 dark:bg-secondary-dark-bg md:w-56 p-4 pt-9 rounded-2xl shadow-xl hover:drop-shadow-xl cursor-pointer'
            >
              <button
                type='button'
                style={{ color: item.iconColor, backgroundColor: item.iconBg }}
                className="text-2xl opacity-0.9 rounded-full p-4 hover:drop-shadow-xl"
              >
                {item.icon}
              </button>
              <p className='mt-3'>
                <span className='text-lg font-semibold'>
                  {item.amount}
                </span>
                <span className={`text-sm text-${item.pcColor} ml-2`}>
                  {item.percentage}
                </span>
              </p>

              <p className='text-sm text-gray-400 mt-1'>{item.title}</p>
            </div>
          ))}
        </div>
      </div>

    </section>
  );
}

export default Summary;

