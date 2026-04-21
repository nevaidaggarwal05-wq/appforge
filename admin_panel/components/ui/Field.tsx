import type { ReactNode } from 'react';

interface FieldProps {
  label: string;
  hint?: string;
  children: ReactNode;
  /** render label inline to the right of children (for switches) */
  inline?: boolean;
}

export function Field({ label, hint, children, inline }: FieldProps) {
  if (inline) {
    return (
      <div className="flex items-center justify-between py-2">
        <div className="flex-1 mr-4">
          <div className="text-sm font-medium">{label}</div>
          {hint && <div className="text-xs text-muted-foreground mt-0.5">{hint}</div>}
        </div>
        {children}
      </div>
    );
  }
  return (
    <div className="mb-4">
      <label className="text-sm font-medium block mb-1">{label}</label>
      {children}
      {hint && <div className="text-xs text-muted-foreground mt-1">{hint}</div>}
    </div>
  );
}
