import { getAdminSummary } from "@/lib/admin";
import { grantCredits, updateUserFlags } from "@/app/actions";

export const dynamic = "force-dynamic";

export default async function AdminHome({
  searchParams
}: {
  searchParams?: Promise<{ email?: string }>;
}) {
  const params = await searchParams;
  const email = params?.email ?? "";
  const summary = await getAdminSummary({ email });

  return (
    <main>
      <h1>中文写字管理后台</h1>
      <p>查看用户额度、登录/使用统计、VIP/block 状态和最近识别记录。</p>

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
        <div className="metric">
          <p>平均识别耗时</p>
          <strong>{formatMs(summary.averageDurationMs)}</strong>
        </div>
      </section>

      <section className="panel">
        <div className="section-heading">
          <h2>用户管理</h2>
          <form className="search-form">
            <input name="email" placeholder="按邮箱搜索" defaultValue={email} />
            <button type="submit">搜索</button>
          </form>
        </div>

        <table>
          <thead>
            <tr>
              <th>用户</th>
              <th>额度</th>
              <th>登录</th>
              <th>使用</th>
              <th>最近地点</th>
              <th>状态</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {summary.users.map((user) => (
              <tr key={user.id}>
                <td>
                  <div>{user.email ?? "Guest"}</div>
                  <div className="code">{user.id}</div>
                  <div className="muted">注册：{formatDate(user.createdAt)}</div>
                </td>
                <td>
                  <strong>{user.remainingCredits}</strong>
                  <div className="muted">总 {user.totalCredits} / 已用 {user.usedCredits}</div>
                </td>
                <td>
                  <strong>{user.loginCount}</strong>
                  <div className="muted">{formatDate(user.lastLoginAt)}</div>
                </td>
                <td>
                  <strong>{user.totalUsageCount}</strong>
                  <div className="muted">{formatDate(user.lastUsedAt)}</div>
                </td>
                <td>{[user.lastLoginCity, user.lastLoginCountry].filter(Boolean).join(", ") || "-"}</td>
                <td>
                  <div className="badges">
                    <span className={`badge ${user.accountType === "email" ? "good" : ""}`}>{user.accountType}</span>
                    {user.isVip ? <span className="badge good">VIP</span> : null}
                    {user.isBlocked ? <span className="badge danger">Blocked</span> : null}
                  </div>
                </td>
                <td>
                  <form action={updateUserFlags} className="inline-form">
                    <input type="hidden" name="userID" value={user.id} />
                    <label>
                      <input type="checkbox" name="isVip" defaultChecked={user.isVip} /> VIP
                    </label>
                    <label>
                      <input type="checkbox" name="isBlocked" defaultChecked={user.isBlocked} /> Block
                    </label>
                    <button type="submit">保存</button>
                  </form>
                  <form action={grantCredits} className="inline-form">
                    <input type="hidden" name="userID" value={user.id} />
                    <input name="credits" type="number" min="1" max="10000" placeholder="额度" />
                    <button type="submit">加额度</button>
                  </form>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
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
              <th>耗时</th>
              <th>模型</th>
            </tr>
          </thead>
          <tbody>
            {summary.recentUsage.map((event) => (
              <tr key={event.id}>
                <td>{new Date(event.createdAt).toLocaleString("zh-CN")}</td>
                <td className="code">{event.userId}</td>
                <td>{event.transcript}</td>
                <td>{event.targetText}</td>
                <td>
                  <strong>{formatMs(event.totalDurationMs)}</strong>
                  <div className="muted">转写 {formatMs(event.transcribeDurationMs)}</div>
                  <div className="muted">提取 {formatMs(event.extractDurationMs)}</div>
                </td>
                <td>
                  <div className="code">{event.transcribeModel ?? "-"}</div>
                  <div className="code muted">{event.textModel ?? "-"}</div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </main>
  );
}

function formatDate(value: string | null) {
  if (!value) return "-";
  return new Date(value).toLocaleString("zh-CN");
}

function formatMs(value: number | null) {
  if (!value) return "-";
  if (value >= 1000) return `${(value / 1000).toFixed(1)}s`;
  return `${value}ms`;
}
