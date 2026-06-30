import { useState } from "react";
import {
  Alert,
  AlertAction,
  AlertDescription,
  AlertTitle,
  Badge,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
  Checkbox,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  Input,
  Label,
  Popover,
  PopoverContent,
  PopoverDescription,
  PopoverHeader,
  PopoverTitle,
  PopoverTrigger,
  Progress,
  RadioGroup,
  RadioGroupItem,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Separator,
  Slider,
  Switch,
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
  Textarea,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@asass/ui";

function App() {
  const [notificationsEnabled, setNotificationsEnabled] = useState(true);
  const [autoDeployEnabled, setAutoDeployEnabled] = useState(false);
  const [selectedPlan, setSelectedPlan] = useState("pro");
  const [selectedRole, setSelectedRole] = useState("admin");
  const [completion, setCompletion] = useState([72]);

  return (
    <main className="min-h-screen bg-background text-foreground">
      <div className="mx-auto flex max-w-7xl flex-col gap-6 px-6 py-10">
        <section className="space-y-4">
          <div className="space-y-2">
            <div className="flex flex-wrap items-center gap-2">
              <Badge>Admin Demo</Badge>
              <Badge variant="secondary">shadcn/ui</Badge>
              <Badge variant="outline">Monorepo</Badge>
            </div>
            <h1 className="text-3xl font-semibold tracking-tight">
              @asass/ui Component Showcase
            </h1>
            <p className="max-w-3xl text-sm text-muted-foreground">
              This page demonstrates every shadcn component imported in this
              file so you can verify exports, styles, and interaction states in
              one place.
            </p>
          </div>

          <Alert>
            <AlertTitle>UI package wired successfully</AlertTitle>
            <AlertDescription>
              The admin app is consuming shared components from `@asass/ui` and
              rendering them with the shared global styles.
            </AlertDescription>
            <AlertAction>
              <Button size="sm" variant="outline">
                Review Setup
              </Button>
            </AlertAction>
          </Alert>
        </section>

        <section className="grid gap-6 xl:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle>Buttons and Feedback</CardTitle>
              <CardDescription>
                Basic actions, status badges, progress, and sliders.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="flex flex-wrap gap-3">
                <Button>Primary</Button>
                <Button variant="secondary">Secondary</Button>
                <Button variant="outline">Outline</Button>
                <Button variant="ghost">Ghost</Button>
                <Button variant="destructive">Danger</Button>
                <Button variant="link">Link Button</Button>
              </div>

              <div className="flex flex-wrap gap-2">
                <Badge>Default</Badge>
                <Badge variant="secondary">Secondary</Badge>
                <Badge variant="outline">Outline</Badge>
                <Badge variant="destructive">Destructive</Badge>
              </div>

              <div className="space-y-3">
                <div className="flex items-center justify-between text-sm">
                  <span>Release progress</span>
                  <span className="text-muted-foreground">{completion[0]}%</span>
                </div>
                <Progress value={completion[0]} />
                <Slider
                  value={completion}
                  onValueChange={setCompletion}
                  max={100}
                  step={1}
                />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Form Controls</CardTitle>
              <CardDescription>
                Inputs, textarea, checkbox, switch, radio group, and select.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-5">
              <div className="space-y-2">
                <Label htmlFor="project-name">Project name</Label>
                <Input
                  id="project-name"
                  defaultValue="ASASS Admin Console"
                  placeholder="Enter project name"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="project-description">Description</Label>
                <Textarea
                  id="project-description"
                  defaultValue="A shared admin demo page for validating shadcn components in the monorepo."
                />
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <div className="flex items-center gap-3">
                  <Checkbox
                    id="notifications"
                    checked={notificationsEnabled}
                    onCheckedChange={(value: boolean | "indeterminate") =>
                      setNotificationsEnabled(value === true)
                    }
                  />
                  <Label htmlFor="notifications">
                    Enable notification center
                  </Label>
                </div>

                <div className="flex items-center gap-3">
                  <Switch
                    checked={autoDeployEnabled}
                    onCheckedChange={setAutoDeployEnabled}
                  />
                  <Label>Enable auto deploy</Label>
                </div>
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label>Workspace role</Label>
                  <RadioGroup value={selectedRole} onValueChange={setSelectedRole}>
                    <div className="flex items-center gap-2">
                      <RadioGroupItem value="admin" id="role-admin" />
                      <Label htmlFor="role-admin">Admin</Label>
                    </div>
                    <div className="flex items-center gap-2">
                      <RadioGroupItem value="editor" id="role-editor" />
                      <Label htmlFor="role-editor">Editor</Label>
                    </div>
                    <div className="flex items-center gap-2">
                      <RadioGroupItem value="viewer" id="role-viewer" />
                      <Label htmlFor="role-viewer">Viewer</Label>
                    </div>
                  </RadioGroup>
                </div>

                <div className="space-y-2">
                  <Label>Subscription plan</Label>
                  <Select value={selectedPlan} onValueChange={setSelectedPlan}>
                    <SelectTrigger className="w-full">
                      <SelectValue placeholder="Select a plan" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="starter">Starter</SelectItem>
                      <SelectItem value="pro">Pro</SelectItem>
                      <SelectItem value="enterprise">Enterprise</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </CardContent>
            <CardFooter className="justify-between text-sm text-muted-foreground">
              <span>Role: {selectedRole}</span>
              <span>Plan: {selectedPlan}</span>
            </CardFooter>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Overlay Components</CardTitle>
              <CardDescription>
                Dialog, popover, and tooltip interactions.
              </CardDescription>
            </CardHeader>
            <CardContent className="flex flex-wrap gap-3">
              <Dialog>
                <DialogTrigger asChild>
                  <Button>Open Dialog</Button>
                </DialogTrigger>
                <DialogContent>
                  <DialogHeader>
                    <DialogTitle>Create workspace</DialogTitle>
                    <DialogDescription>
                      Use the shared dialog primitives from `@asass/ui` to
                      compose modal workflows.
                    </DialogDescription>
                  </DialogHeader>
                  <div className="space-y-3">
                    <div className="space-y-2">
                      <Label htmlFor="workspace-name">Workspace name</Label>
                      <Input
                        id="workspace-name"
                        placeholder="e.g. Hunan Evaluation"
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="workspace-note">Note</Label>
                      <Textarea
                        id="workspace-note"
                        placeholder="Describe the initial workspace setup"
                      />
                    </div>
                  </div>
                  <DialogFooter showCloseButton>
                    <Button>Create</Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>

              <Popover>
                <PopoverTrigger asChild>
                  <Button variant="outline">Open Popover</Button>
                </PopoverTrigger>
                <PopoverContent>
                  <PopoverHeader>
                    <PopoverTitle>Quick Summary</PopoverTitle>
                    <PopoverDescription>
                      Shared UI can expose small read-only surfaces just as
                      easily as complex forms.
                    </PopoverDescription>
                  </PopoverHeader>
                  <div className="grid gap-2 text-sm">
                    <div className="flex items-center justify-between">
                      <span>Members</span>
                      <Badge variant="secondary">18</Badge>
                    </div>
                    <div className="flex items-center justify-between">
                      <span>Projects</span>
                      <Badge variant="secondary">6</Badge>
                    </div>
                  </div>
                </PopoverContent>
              </Popover>

              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="secondary">Hover Tooltip</Button>
                </TooltipTrigger>
                <TooltipContent>
                  Tooltip content from the shared UI package.
                </TooltipContent>
              </Tooltip>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Tabs Layout</CardTitle>
              <CardDescription>
                A compact example of tabbed navigation for admin pages.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Tabs defaultValue="overview" className="w-full">
                <TabsList>
                  <TabsTrigger value="overview">Overview</TabsTrigger>
                  <TabsTrigger value="members">Members</TabsTrigger>
                  <TabsTrigger value="security">Security</TabsTrigger>
                </TabsList>
                <TabsContent value="overview" className="space-y-3 pt-4">
                  <p className="text-sm text-muted-foreground">
                    Workspace health, usage metrics, and release progress can be
                    grouped into an overview tab.
                  </p>
                  <Separator />
                  <div className="grid gap-3 md:grid-cols-3">
                    <Badge variant="outline">99.95% uptime</Badge>
                    <Badge variant="outline">2 pending approvals</Badge>
                    <Badge variant="outline">12 active automations</Badge>
                  </div>
                </TabsContent>
                <TabsContent value="members" className="space-y-3 pt-4">
                  <p className="text-sm text-muted-foreground">
                    Member management surfaces can reuse the same shared form
                    and feedback components.
                  </p>
                  <Separator />
                  <div className="space-y-2 text-sm">
                    <div className="flex items-center justify-between">
                      <span>Admins</span>
                      <span>3</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span>Editors</span>
                      <span>8</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span>Viewers</span>
                      <span>21</span>
                    </div>
                  </div>
                </TabsContent>
                <TabsContent value="security" className="space-y-3 pt-4">
                  <p className="text-sm text-muted-foreground">
                    Security settings often combine switches, badges, and
                    dialogs to manage sensitive actions.
                  </p>
                  <Separator />
                  <div className="flex items-center justify-between rounded-lg border p-3">
                    <div>
                      <div className="text-sm font-medium">
                        Require MFA for admins
                      </div>
                      <div className="text-xs text-muted-foreground">
                        Strengthen access control for critical roles.
                      </div>
                    </div>
                    <Switch checked />
                  </div>
                </TabsContent>
              </Tabs>
            </CardContent>
          </Card>
        </section>
      </div>
    </main>
  );
}

export default App;
