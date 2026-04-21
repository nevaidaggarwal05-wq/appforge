import { redirect } from 'next/navigation';
export default function AppDetailPage({ params }: { params: { id: string } }) {
  redirect(`/apps/${params.id}/config`);
}
