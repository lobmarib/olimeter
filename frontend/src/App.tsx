import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { ConfigProvider, Layout, Menu } from "antd";
import { Link, useLocation } from "react-router-dom";

const { Header, Content } = Layout;

function AppLayout() {
  const location = useLocation();

  const menuItems = [
    { key: "/dispensing", label: <Link to="/dispensing">Dispensing</Link> },
    { key: "/history", label: <Link to="/history">History</Link> },
    { key: "/admin", label: <Link to="/admin">Admin</Link> },
  ];

  return (
    <Layout style={{ minHeight: "100vh" }}>
      <Header style={{ display: "flex", alignItems: "center" }}>
        <div style={{ color: "#fff", fontWeight: "bold", marginRight: 24 }}>
          OliMeeter
        </div>
        <Menu
          theme="dark"
          mode="horizontal"
          selectedKeys={[location.pathname]}
          items={menuItems}
          style={{ flex: 1 }}
        />
      </Header>
      <Content style={{ padding: "24px 48px" }}>
        <Routes>
          {/* Phase 3 (US1): DispensingPage */}
          <Route path="/dispensing" element={<div>Dispensing Page (Phase 3)</div>} />
          {/* Phase 6 (US4): HistoryPage */}
          <Route path="/history" element={<div>History Page (Phase 6)</div>} />
          {/* Phase 7 (US5): AdminPage */}
          <Route path="/admin" element={<div>Admin Page (Phase 7)</div>} />
          <Route path="*" element={<Navigate to="/dispensing" replace />} />
        </Routes>
      </Content>
    </Layout>
  );
}

export default function App() {
  return (
    <ConfigProvider>
      <BrowserRouter>
        <AppLayout />
      </BrowserRouter>
    </ConfigProvider>
  );
}
