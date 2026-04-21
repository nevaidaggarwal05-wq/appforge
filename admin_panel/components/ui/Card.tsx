import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface CardProps {
  title?: string;
  description?: string;
  children: ReactNode;
  className?: string;
}

export function Card({ title, description, children, className }: CardProps) {
  return (
    <section className={cn('card', className)}>
      {title && (
        <header className="mb-4">
          <h2 className="card-title">{title}</h2>
          {description && <p className="text-sm text-muted-foreground">{description}</p>}
        </header>
      )}
      <div>{children}</div>
    </section>
  );
}
