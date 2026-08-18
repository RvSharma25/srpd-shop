import './globals.css';
import './product-card-fix.css';
import { ReactNode } from 'react';
export const metadata={title:'SRPD Shop',description:'Simple, dynamic campus shop'};
export default function RootLayout({children}:{children:ReactNode}){return <html lang="en"><body>{children}</body></html>}
