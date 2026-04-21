import { cn } from '@/lib/utils';
import type { ButtonHTMLAttributes, ReactNode } from 'react';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  children: ReactNode;
}

export function Button({ variant = 'primary', className, children, ...props }: ButtonProps) {
  const variantClass =
    variant === 'primary'  ? 'btn-primary'  :
    variant === 'danger'   ? 'btn-danger'   :
                             'btn-secondary';
  return (
    <button className={cn(variantClass, className)} {...props}>
      {children}
    </button>
  );
}
