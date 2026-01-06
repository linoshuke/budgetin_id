import { AuthPage } from "@refinedev/antd";

export const Login = () => {
    return (
        <AuthPage
            type="login"
            title={<h2 style={{ textAlign: "center" }}>Budgetin Admin</h2>}
            formProps={{
                initialValues: {
                    email: "",
                    password: "",
                },
            }}
        />
    );
};
