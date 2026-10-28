import { createContext,useContext,useEffect,useState,type ReactNode } from 'react';
const LanguageContext=createContext({lang:'en',toggle:()=>{},t:(en:string,ar:string)=>en});
export function LanguageProvider({children}:{children:ReactNode}){const [lang,setLang]=useState('en');useEffect(()=>{setLang(localStorage.getItem('bmp-language')==='ar'?'ar':'en');},[]);useEffect(()=>{document.documentElement.lang=lang;document.documentElement.dir=lang==='ar'?'rtl':'ltr';},[lang]);return <LanguageContext.Provider value={{lang,t:(en,ar)=>lang==='ar'?ar:en,toggle:()=>setLang(l=>{const next=l==='en'?'ar':'en';localStorage.setItem('bmp-language',next);return next;})}}>{children}</LanguageContext.Provider>;}
export const useLanguage=()=>useContext(LanguageContext);
