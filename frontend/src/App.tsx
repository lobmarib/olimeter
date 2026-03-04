import { useEffect, useState } from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { ConfigProvider, Layout, Menu, Button, Space, Typography } from "antd";
import { Link, useLocation } from "react-router-dom";
import { initKeycloak, getUsername, hasRole, logout } from "./services/auth";

const { Header, Content } = Layout;
const { Text } = Typography;

function AppLayout() {
  const location = useLocation();
  const username = getUsername();

  const menuItems = [
    { key: "/dispensing", label: <Link to="/dispensing">Dispensing</Link> },
    { key: "/history", label: <Link to="/history">History</Link> },
    ...(hasRole("admin")
      ? [{ key: "/admin", label: <Link to="/admin">Admin</Link> }]
      : []),
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
        <Space>
          <Text style={{ color: "#fff" }}>{username}</Text>
          <Button size="small" onClick={logout}>
            Logout
          </Button>
        </Space>
      </Header>
      <Content style={{ padding: "24px 48px" }}>
        <Routes>
          {/* Phase 3 (US1): DispensingPage */}
          <Route path="/dispensing" element={<div>Dispensing Page (Phase 4)</div>} />
          {/* Phase 6 (US4): HistoryPage */}
          <Route path="/history" element={<div>History Page (Phase 7)</div>} />
          {/* Phase 7 (US5): AdminPage */}
          <Route path="/admin" element={<div>Admin Page (Phase 8)</div>} />
          <Route path="*" element={<Navigate to="/dispensing" replace />} />
        </Routes>
      </Content>
    </Layout>
  );
}

export default function App() {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    initKeycloak().then((authenticated) => {
      if (authenticated) setReady(true);
    });
  }, []);

  if (!ready) {
    return (
      <div style={{ display: "flex", justifyContent: "center", alignItems: "center", height: "100vh" }}>
        Authenticating...
      </div>
    );
  }

  return (
    <ConfigProvider>
      <BrowserRouter>
        <AppLayout />
      </BrowserRouter>
    </ConfigProvider>
  );
}
