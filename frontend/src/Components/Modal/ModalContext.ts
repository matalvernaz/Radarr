import { createContext } from 'react';

interface ModalContextType {
    headerId: string;
}

const ModalContext = createContext<ModalContextType>({ headerId: '' });

export default ModalContext;
