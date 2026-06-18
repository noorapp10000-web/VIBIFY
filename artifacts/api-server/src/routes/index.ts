import { Router, type IRouter } from "express";
import healthRouter from "./health";
import searchRouter from "./search";
import streamRouter from "./stream";

const router: IRouter = Router();

router.use(healthRouter);
router.use(searchRouter);
router.use(streamRouter);

export default router;
