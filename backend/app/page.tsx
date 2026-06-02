import { getAdminSummary } from "@/lib/admin";

export const dynamic = "force-dynamic";

export default async function AdminHome() {
  const summary = await getAdminSummary();

  return (
    <main>
      <h1>中文写字管理后台</h1>
      <p>查看用户额度、使用量和最近识别记录。正式上线前可以继续加登录保护和运营工具。</p>

      <section className="grid">
        <div className="metric">
          <p>用户数</p>
          <strong>{summary.userCount}</strong>
        </div>
        <div className="metric">
          <p>总使用次数</p>
          <strong>{summary.usageCount}</strong>
        </div>
        <div className="metric">
          <p>剩余额度合计</p>
          <strong>{summary.remainingCredits}</strong>
        </div>
      </section>

      <section className="panel">
        <h2>最近使用</h2>
        <table>
          <thead>
            <tr>
              <th>时间</th>
              <th>用户</th>
              <th>转录</th>
              <th>提取文字</th>
            </tr>
          </thead>
          <tbody>
            {summary.recentUsage.map((event) => (
              <tr key={event.id}>
                <td>{new Date(event.createdAt).toLocaleString("zh-CN")}</td>
                <td className="code">{event.userId}</td>
                <td>{event.transcript}</td>
                <td>{event.targetText}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </main>
  );
}
