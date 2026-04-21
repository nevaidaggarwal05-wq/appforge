import Link from 'next/link';
import { ChevronLeft } from 'lucide-react';
import NewAppForm from './NewAppForm';

export default function NewAppPage() {
  return (
    <div className="max-w-xl">
      <Link href="/apps" className="text-sm text-muted-foreground flex items-center gap-1 mb-4 hover:text-foreground">
        <ChevronLeft size={14} /> Back to apps
      </Link>
      <h1 className="text-2xl font-bold mb-1">New App</h1>
      <p className="text-sm text-muted-foreground mb-6">
        You can tweak everything else after creation.
      </p>
      <NewAppForm />
    </div>
  );
}
