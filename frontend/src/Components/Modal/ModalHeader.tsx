import React, { useContext } from 'react';
import ModalContext from './ModalContext';
import styles from './ModalHeader.css';

interface ModalHeaderProps extends React.HTMLAttributes<HTMLDivElement> {
  children?: React.ReactNode;
}

function ModalHeader({ children, ...otherProps }: ModalHeaderProps) {
  const { headerId } = useContext(ModalContext);

  return (
    <div id={headerId} className={styles.modalHeader} {...otherProps}>
      {children}
    </div>
  );
}

export default ModalHeader;
