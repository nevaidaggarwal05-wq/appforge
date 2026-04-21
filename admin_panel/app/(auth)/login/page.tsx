'use client';
import { useState } from 'react';
import { getBrowserClient } from '@/lib/supabase/client';
import { toast } from 'sonner';
import { Button } from '@/components/ui/Button';
import { Mail, KeyRound, ArrowLeft } from 'lucide-react';

type Stage = 'email' | 'code';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [code, setCode]   = useState('');
  const [stage, setStage] = useState<Stage>('email');
  const [loading, setLoading] = useState(false);

  const sendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email) return;
    setLoading(true);
    const supabase = getBrowserClient();
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: true }
    });
    setLoading(false);
    if (error) { toast.error(error.message); return; }
    toast.success('Check your email for the 6-digit code');
    setStage('code');
  };

  const verifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (code.length !== 6) return;
    setLoading(true);
    const supabase = getBrowserClient();
    const { error } = await supabase.auth.verifyOtp({ email, token: code, type: 'email' });
    setLoading(false);
    if (error) { toast.error(error.message); return; }
    window.location.href = '/apps';
  };

  return (
    <div className="w-full max-w-sm mx-4">
      <div className="bg-background rounded-lg border p-8 shadow-sm">
        <h1 className="text-2xl font-bold mb-1">AppForge</h1>
        <p className="text-sm text-muted-foreground mb-6">
          Sign in to manage your mobile apps
        </p>

        {stage === 'email' ? (
          <form onSubmit={sendOtp}>
            <label className="text-sm font-medium block mb-2">Email address</label>
            <div className="relative">
              <Mail className="absolute left-3 top-2.5 text-muted-foreground" size={16} />
              <input
                type="email"
                autoFocus
                required
                value={email}
                onChange={e => setEmail(e.target.value)}
                className="input pl-9"
                placeholder="you@example.com"
              />
            </div>
            <Button type="submit" disabled={loading || !email} className="w-full mt-4">
              {loading ? 'Sending code...' : 'Send 6-digit code'}
            </Button>
            <p className="text-xs text-muted-foreground mt-4 text-center">
              New here? Your account is created automatically on first sign-in.
            </p>
          </form>
        ) : (
          <form onSubmit={verifyOtp}>
            <div className="mb-2 flex items-center justify-between">
              <label className="text-sm font-medium">Code from {email}</label>
              <button
                type="button"
                onClick={() => { setStage('email'); setCode(''); }}
                className="text-xs text-muted-foreground hover:text-foreground flex items-center gap-1"
              >
                <ArrowLeft size={12} /> Change email
              </button>
            </div>
            <div className="relative">
              <KeyRound className="absolute left-3 top-2.5 text-muted-foreground" size={16} />
              <input
                type="text"
                autoFocus
                inputMode="numeric"
                pattern="[0-9]{6}"
                maxLength={6}
                required
                value={code}
                onChange={e => setCode(e.target.value.replace(/\D/g, ''))}
                className="input pl-9 tracking-[0.4em] font-mono text-center"
                placeholder="123456"
              />
            </div>
            <Button type="submit" disabled={loading || code.length !== 6} className="w-full mt-4">
              {loading ? 'Verifying...' : 'Verify & sign in'}
            </Button>
          </form>
        )}
      </div>
    </div>
  );
}
