'use client';
import { cn } from '@/lib/utils';

interface SwitchProps {
  checked: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
  id?: string;
}

export function Switch({ checked, onChange, disabled, id }: SwitchProps) {
  return (
    <button
      id={id}
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      data-state={checked ? 'on' : 'off'}
      className={cn('switch', disabled && 'opacity-50 cursor-not-allowed')}
    >
      <span className="switch-thumb" />
    </button>
  );
}
