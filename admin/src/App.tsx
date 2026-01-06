import { Refine } from "@refinedev/core";
import { ThemedLayoutV2, useNotificationProvider, RefineThemes } from "@refinedev/antd";
import { BrowserRouter, Routes, Route, Outlet } from "react-router";
import { ConfigProvider, App as AntdApp } from "antd";
import routerProvider from "@refinedev/react-router";

import "@refinedev/antd/dist/reset.css";

import { dataProvider } from "./providers/dataProvider";
import { authProvider } from "./providers/authProvider";

// Resources
import { UserList, UserCreate, UserEdit, UserShow } from "./pages/users";
import { WalletList, WalletCreate, WalletEdit, WalletShow } from "./pages/wallets";
import { TransactionList, TransactionCreate, TransactionEdit, TransactionShow } from "./pages/transactions";
import { Dashboard } from "./pages/dashboard";
import { Login } from "./pages/login";

import {
    DashboardOutlined,
    UserOutlined,
    WalletOutlined,
    TransactionOutlined,
} from "@ant-design/icons";

function App() {
    return (
        <BrowserRouter>
            <ConfigProvider theme={RefineThemes.Blue}>
                <AntdApp>
                    <Refine
                        dataProvider={dataProvider}
                        authProvider={authProvider}
                        routerProvider={routerProvider}
                        notificationProvider={useNotificationProvider}
                        resources={[
                            {
                                name: "dashboard",
                                list: "/",
                                meta: {
                                    label: "Dashboard",
                                    icon: <DashboardOutlined />,
                                },
                            },
                            {
                                name: "users",
                                list: "/users",
                                create: "/users/create",
                                edit: "/users/edit/:id",
                                show: "/users/show/:id",
                                meta: {
                                    label: "Users",
                                    icon: <UserOutlined />,
                                },
                            },
                            {
                                name: "wallets",
                                list: "/wallets",
                                create: "/wallets/create",
                                edit: "/wallets/edit/:id",
                                show: "/wallets/show/:id",
                                meta: {
                                    label: "Wallets",
                                    icon: <WalletOutlined />,
                                },
                            },
                            {
                                name: "transactions",
                                list: "/transactions",
                                create: "/transactions/create",
                                edit: "/transactions/edit/:id",
                                show: "/transactions/show/:id",
                                meta: {
                                    label: "Transactions",
                                    icon: <TransactionOutlined />,
                                },
                            },
                        ]}
                        options={{
                            syncWithLocation: true,
                            warnWhenUnsavedChanges: true,
                        }}
                    >
                        <Routes>
                            <Route path="/login" element={<Login />} />
                            <Route
                                element={
                                    <ThemedLayoutV2
                                        Title={() => <h2 style={{ margin: 0, color: "#fff" }}>Budgetin Admin</h2>}
                                    >
                                        <Outlet />
                                    </ThemedLayoutV2>
                                }
                            >
                                <Route index element={<Dashboard />} />
                                <Route path="/users">
                                    <Route index element={<UserList />} />
                                    <Route path="create" element={<UserCreate />} />
                                    <Route path="edit/:id" element={<UserEdit />} />
                                    <Route path="show/:id" element={<UserShow />} />
                                </Route>
                                <Route path="/wallets">
                                    <Route index element={<WalletList />} />
                                    <Route path="create" element={<WalletCreate />} />
                                    <Route path="edit/:id" element={<WalletEdit />} />
                                    <Route path="show/:id" element={<WalletShow />} />
                                </Route>
                                <Route path="/transactions">
                                    <Route index element={<TransactionList />} />
                                    <Route path="create" element={<TransactionCreate />} />
                                    <Route path="edit/:id" element={<TransactionEdit />} />
                                    <Route path="show/:id" element={<TransactionShow />} />
                                </Route>
                            </Route>
                        </Routes>
                    </Refine>
                </AntdApp>
            </ConfigProvider>
        </BrowserRouter>
    );
}

export default App;
