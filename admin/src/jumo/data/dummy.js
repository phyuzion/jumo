import React from 'react';
import { AiOutlineCalendar, AiOutlineShoppingCart, AiOutlineAreaChart, AiOutlineBarChart, AiOutlineStock } from 'react-icons/ai';
import { FiShoppingBag, FiEdit, FiPieChart, FiBarChart, FiCreditCard, FiStar, FiShoppingCart } from 'react-icons/fi';
import { BsKanban, BsBarChart, BsBoxSeam, BsCurrencyDollar, BsShield, BsChatLeft } from 'react-icons/bs';
import { BiColorFill } from 'react-icons/bi';
import { IoMdContacts } from 'react-icons/io';
import { RiContactsLine, RiStockLine } from 'react-icons/ri';
import { MdOutlineSupervisorAccount } from 'react-icons/md';
import { HiOutlineRefresh } from 'react-icons/hi';
import { TiTick } from 'react-icons/ti';
import { GiLouvrePyramid } from 'react-icons/gi';
import { GrLocation } from 'react-icons/gr';



export const gridTransactionStatus = (props) => (
  <button
    type="button"
    style={{ background: props.StatusBg }}
    className="text-white py-1 px-2 capitalize rounded-2xl text-md"
  >
    {props.Status}
  </button>
);

const gridEmployeeProfile = (props) => (
  <div className="flex items-center gap-2">
    
    <p>{props.Name}</p>
  </div>
);


export const earningData = [
  {
    icon: <MdOutlineSupervisorAccount />,
    amount: '39,354',
    percentage: '-4%',
    title: '유저수',
    iconColor: '#03C9D7',
    iconBg: '#E5FAFB',
    pcColor: 'red-600',
  },
  {
    icon: <BsBoxSeam />,
    amount: '4,396',
    percentage: '+23%',
    title: '고객수',
    iconColor: 'rgb(255, 244, 229)',
    iconBg: 'rgb(254, 201, 15)',
    pcColor: 'green-600',
  },
  {
    icon: <HiOutlineRefresh />,
    amount: '423,39',
    percentage: '+38%',
    title: '콜수',
    iconColor: 'rgb(228, 106, 118)',
    iconBg: 'rgb(255, 244, 229)',

    pcColor: 'green-600',
  },
];

export const transactionsGrid = [
  
  {
    field: 'OrderItems',
    headerText: 'Transaction',
    width: '300',
    editType: 'dropdownedit',
    textAlign: 'Center',
  },
  {
    field: 'HolderName',
    headerText: 'Wallet Addr',
    width: '300',
    textAlign: 'Center',
  },
  {
    field: 'TotalAmount',
    headerText: 'Amount',
    format: 'C2',
    textAlign: 'Center',
    editType: 'numericedit',
    width: '100',
  },
  {
    headerText: 'Status',
    template: gridTransactionStatus,
    field: 'OrderItems',
    textAlign: 'Center',
    width: '120',
  },
  {
    field: 'OrderID',
    headerText: 'ID',
    width: '100',
    textAlign: 'Center',
  },

];



export const transactionsData = [
  {
    OrderID: 10248,
    HolderName: '098oiujyt... -> 764erfct7...',

    TotalAmount: 32.38,
    OrderItems: '123qweasd456rtyfgh...',
    Location: 'USA',
    Status: 'pending',
    StatusBg: '#FB9678',
  },
  {
    OrderID: 345653,
    HolderName: '098oiujyt... -> 764erfct7...',
    TotalAmount: 56.34,
    OrderItems: '123qweasd456rtyfgh...',
    Location: 'Delhi',
    Status: 'complete',
    StatusBg: '#8BE78B',
  },
];
